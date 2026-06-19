# AWS ↔ Azure VPN Destroy / Restore

## Destroy (비용 절감 시)

### 1. Azure VPN Connection 먼저
```bash
cd terraform-azure
terraform destroy -var-file=main.tfvars -target=azurerm_virtual_network_gateway_connection.to_aws -target=azurerm_virtual_network_gateway_connection.to_aws_tunnel2
```

### 2. Azure VPN Gateway + Public IP + Local Network Gateway
```bash
cd terraform-azure
terraform destroy -var-file=main.tfvars -target=azurerm_virtual_network_gateway.main -target=azurerm_public_ip.vpn_gateway -target=azurerm_local_network_gateway.aws -target=azurerm_local_network_gateway.aws_tunnel2
```

### 3. AWS VPN Connection + Customer Gateway
```bash
cd terraform
terraform destroy -var-file=main.tfvars -target=aws_vpn_connection_route.azure -target=aws_vpn_connection.azure -target=aws_customer_gateway.azure
```

---

## Restore (다시 올릴 시)

### 1. Azure VPN Gateway + Public IP 먼저
```bash
cd terraform-azure
terraform apply -var-file=main.tfvars -target=azurerm_public_ip.vpn_gateway -target=azurerm_virtual_network_gateway.main
```

### 2. Azure VPN Gateway 새 공인 IP 확인 → terraform/main.tfvars에 입력
> ⚠️ Destroy 후 재생성하면 공인 IP가 바뀜 — 반드시 새 IP로 업데이트해야 함

```bash
cd terraform-azure
terraform output vpn_gateway_public_ip
```

`terraform/main.tfvars`에 입력:
```hcl
azure_vpn_gateway_ip = "새로 할당된 Azure VPN Gateway IP"
vpn_shared_key       = "기존 PSK 값"
```

### 3. AWS VPN 적용
```bash
cd terraform
terraform apply -var-file=main.tfvars -target=aws_customer_gateway.azure -target=aws_vpn_connection.azure -target=aws_vpn_connection_route.azure
```

### 4. AWS 터널 IP 확인 → terraform-azure/main.tfvars에 입력
```bash
cd terraform
terraform output -raw vpn_azure_tunnel1_address
terraform output -raw vpn_azure_tunnel2_address
```

`terraform-azure/main.tfvars`에 입력:
```hcl
aws_vpn_tunnel_ip  = "위에서 나온 tunnel1 IP"
aws_vpn_tunnel2_ip = "위에서 나온 tunnel2 IP"
```

### 5. Azure Local Network Gateway
```bash
cd terraform-azure
terraform apply -var-file=main.tfvars -target=azurerm_local_network_gateway.aws -target=azurerm_local_network_gateway.aws_tunnel2
```

### 6. Azure VPN Connection
```bash
cd terraform-azure
terraform apply -var-file=main.tfvars -target=azurerm_virtual_network_gateway_connection.to_aws -target=azurerm_virtual_network_gateway_connection.to_aws_tunnel2
```

> ⚠️ Restore 후 VPN 터널 연결까지 10~15분 소요
> ⚠️ DMS CDC 재시작 필요 (Azure MySQL 복제 끊김)

---

## IDC + DMS Destroy (발표 후 불필요 시)

### 1. DMS Task 먼저
```bash
cd terraform
terraform destroy -var-file=main.tfvars -target=aws_dms_replication_task.full_load -target=aws_dms_replication_task.aurora_to_azure
```

### 2. DMS Endpoints + Instance
```bash
cd terraform
terraform destroy -var-file=main.tfvars -target=aws_dms_endpoint.source -target=aws_dms_endpoint.target -target=aws_dms_endpoint.aurora_source -target=aws_dms_endpoint.azure_target -target=aws_dms_replication_instance.main -target=aws_dms_replication_subnet_group.main
```

### 3. IDC VPN (Customer Gateway 포함)
```bash
cd terraform
terraform destroy -var-file=main.tfvars -target=aws_vpn_connection_route.idc -target=aws_vpn_connection.main -target=aws_customer_gateway.idc -target=aws_vpn_gateway_route_propagation.private_backend -target=aws_vpn_gateway_route_propagation.private_db -target=aws_vpn_gateway.main -target=aws_eip_association.cgw -target=aws_eip.cgw
```

### 4. IDC EC2 + VPC 전체
```bash
cd terraform
terraform destroy -var-file=main.tfvars -target=aws_instance.mysql -target=aws_instance.cgw -target=aws_security_group.mysql -target=aws_security_group.cgw -target=aws_route_table_association.idc_public -target=aws_route_table_association.idc_private -target=aws_route.idc_public_default -target=aws_route.idc_private_to_main_vpc -target=aws_route.idc_private_default -target=aws_route_table.idc_public -target=aws_route_table.idc_private -target=aws_subnet.idc_public -target=aws_subnet.idc_private -target=aws_internet_gateway.idc -target=aws_vpc.idc
```

---

## IDC + DMS Restore (다시 올릴 시)

### 1. IDC EC2 + VPC
```bash
cd terraform
terraform apply -var-file=main.tfvars -target=aws_vpc.idc -target=aws_internet_gateway.idc -target=aws_subnet.idc_public -target=aws_subnet.idc_private -target=aws_route_table.idc_public -target=aws_route_table.idc_private -target=aws_route.idc_public_default -target=aws_route_table_association.idc_public -target=aws_route_table_association.idc_private -target=aws_security_group.cgw -target=aws_security_group.mysql -target=aws_instance.cgw -target=aws_instance.mysql
```

### 2. IDC VPN (Customer Gateway 포함)
```bash
cd terraform
terraform apply -var-file=main.tfvars -target=aws_eip.cgw -target=aws_eip_association.cgw -target=aws_customer_gateway.idc -target=aws_vpn_gateway.main -target=aws_vpn_gateway_route_propagation.private_backend -target=aws_vpn_gateway_route_propagation.private_db -target=aws_vpn_connection.main -target=aws_vpn_connection_route.idc
```

### 3. DMS Endpoints + Instance
```bash
cd terraform
terraform apply -var-file=main.tfvars -target=aws_dms_replication_subnet_group.main -target=aws_dms_replication_instance.main -target=aws_dms_endpoint.source -target=aws_dms_endpoint.target -target=aws_dms_endpoint.aurora_source -target=aws_dms_endpoint.azure_target
```

### 4. DMS Task
```bash
cd terraform
terraform apply -var-file=main.tfvars -target=aws_dms_replication_task.full_load -target=aws_dms_replication_task.aurora_to_azure
```

> ⚠️ EC2 리소스 이름은 ec2.tf에서 확인 후 맞게 수정
> ⚠️ VPN 터널 연결 확인 후 DMS Task 시작할 것
