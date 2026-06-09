# 인프라 전체 배포 런북

> **주의사항**
> - `terraform/` : AWS 인프라 (ap-northeast-2)
> - `terraform-azure/` : Azure DR 인프라 (koreacentral)
> - 작업 전 terraform workspace 확인 (`terraform workspace show`)
>   - `dev` 워크스페이스 = 개인 계정 (dev.tfvars)
>   - `default` 워크스페이스 = 팀 계정 (main.tfvars)

---

## Phase 1 — AWS 기본 인프라

### ① main.tfvars 초기 설정 확인

```hcl
enable_migration = false   # Phase 2 전까지 false — true로 올리면 MySQL EC2/DMS가 같이 생성됨
```

### ② terraform apply

```bash
cd terraform && terraform workspace select default && terraform apply -var-file=main.tfvars
```

주요 생성 리소스: VPC, ECS Cluster/Services, Aurora, API Gateway, ALB, CloudFront, S3, Cognito, OpenSearch 등

### ② ECS 서비스 정상 확인

```bash
aws ecs describe-services --cluster ThreeTier-Cluster --services auth-service hotel-service booking-service review-service support-service --query "services[*].{Name:serviceName,Running:runningCount,Desired:desiredCount}" --output table --region ap-northeast-2
```

---

## Phase 2 — IDC MySQL → Aurora 마이그레이션 (DMS Full Load)

> Aurora에 데이터가 없는 상태. IDC MySQL EC2를 소스로 DMS Full Load 실행.

### ① main.tfvars 설정

```hcl
enable_migration = true
```

### ② terraform apply (MySQL EC2 + DMS 리소스 생성)

```bash
terraform apply -var-file=main.tfvars
```

### ③ IDC ↔ Main VPN 터널 UP 확인

```bash
aws ec2 describe-vpn-connections --filters "Name=tag:Name,Values=*IDC*" --query "VpnConnections[*].VgwTelemetry[*].{IP:OutsideIpAddress,Status:Status}" --output table --region ap-northeast-2
```

### ④ MySQL EC2 MariaDB + seed 완료 확인

```bash
aws ssm start-session --target <mysql-ec2-instance-id> --region ap-northeast-2
```

접속 후:
```bash
mysql -u root -p -e "SHOW DATABASES;"
```

### ⑤ DMS Full Load ARN 확인 후 시작

```bash
aws dms describe-replication-tasks --query "ReplicationTasks[*].{ID:ReplicationTaskIdentifier,ARN:ReplicationTaskArn,Status:Status}" --output table --region ap-northeast-2
```

```bash
aws dms start-replication-task --replication-task-arn <my-migration-task ARN> --start-replication-task-type start-replication --region ap-northeast-2
```

### ⑥ DMS Full Load 완료 확인

```bash
aws dms describe-replication-tasks --query "ReplicationTasks[?ReplicationTaskIdentifier=='my-migration-task'].{Status:Status,Progress:ReplicationTaskStats.FullLoadProgressPercent}" --output table --region ap-northeast-2
```

`FullLoadProgressPercent: 100` 확인 후 다음 단계 진행.

### ⑦ 마이그레이션 완료 후 IDC 리소스 삭제

```hcl
# main.tfvars
enable_migration = false
```

```bash
terraform apply -var-file=main.tfvars
```

MySQL EC2, IDC VPN, DMS Full Load 태스크 자동 삭제.

---

## Phase 3 — AWS ↔ Azure VPN + CDC

> VPN 특성상 양쪽 IP를 교차 입력해야 해서 apply를 두 번 해야 함.

### ① Azure apply (Azure VPN Gateway IP 취득)

```bash
cd terraform-azure && terraform apply -var-file=terraform.tfvars
```

output에서 확인:
```
vpn_gateway_public_ip = "20.249.201.149"  # 예시
```

### ② AWS tfvars 업데이트

`terraform/main.tfvars`:
```hcl
azure_vpn_gateway_ip = "위에서 나온 IP"
```

### ③ AWS apply (AWS VPN Tunnel IP 취득)

```bash
cd terraform && terraform apply -var-file=main.tfvars
```

output에서 확인:
```
vpn_azure_tunnel1_address = "3.35.57.106"  # 예시
```

### ④ Azure tfvars 업데이트

`terraform-azure/terraform.tfvars`:
```hcl
aws_vpn_tunnel_ip = "위에서 나온 IP"
```

### ⑤ Azure apply 재실행 (터널 UP)

```bash
cd terraform-azure && terraform apply -var-file=terraform.tfvars
```

VPN 터널 상태 확인:
```bash
aws ec2 describe-vpn-connections --filters "Name=tag:Name,Values=*Azure*" --query "VpnConnections[*].VgwTelemetry[*].{IP:OutsideIpAddress,Status:Status}" --output table --region ap-northeast-2
```

`Tunnel1: UP` 확인.

### ⑥ Aurora 재부팅 (binlog 파라미터 활성화)

```bash
aws rds failover-db-cluster --db-cluster-identifier threetier-aurora-cluster --region ap-northeast-2
```

완료 확인:
```bash
aws rds describe-db-clusters --db-cluster-identifier threetier-aurora-cluster --query "DBClusters[0].Status" --output text --region ap-northeast-2
```

`available` 확인 후 다음 단계 진행.

### ⑦ dms_replicator 계정 생성 ⚠️ 수동

Aurora에 CDC용 계정 생성:

```sql
CREATE USER 'dms_replicator'@'%' IDENTIFIED BY '<password>';
GRANT REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'dms_replicator'@'%';
GRANT SELECT ON *.* TO 'dms_replicator'@'%';
FLUSH PRIVILEGES;
```

### ⑧ CDC 태스크 시작 ⚠️ 수동

> DMS 태스크가 `full-load-and-cdc` + `DROP_AND_CREATE`로 설정되어 있어
> 스키마 생성 → 데이터 복사 → CDC 전환을 자동으로 처리함.

ARN 확인:
```bash
aws dms describe-replication-tasks --query "ReplicationTasks[*].{ID:ReplicationTaskIdentifier,ARN:ReplicationTaskArn,Status:Status}" --output table --region ap-northeast-2
```

CDC 시작:
```bash
aws dms start-replication-task --replication-task-arn <cdc-aurora-to-azure ARN> --start-replication-task-type start-replication --region ap-northeast-2
```

CDC 복제 상태 확인:
```bash
aws dms describe-replication-tasks --query "ReplicationTasks[?ReplicationTaskIdentifier=='cdc-aurora-to-azure'].{Status:Status,Latency:ReplicationTaskStats.ApplyLatency}" --output table --region ap-northeast-2
```

`Status: running`, `Latency: None(0)` → 정상.

---

## 배포 전체 요약

| 단계 | 작업 | 비고 |
|------|------|------|
| **Phase 1** | | |
| 1-① | AWS terraform apply | 기본 인프라 전체 |
| 1-② | ECS 서비스 확인 | running == desired |
| **Phase 2** | | |
| 2-① | enable_migration=true, apply | MySQL EC2 + DMS 생성 |
| 2-② | IDC VPN UP 확인 | Tunnel1 UP |
| 2-③ | DMS Full Load 시작 | **수동** |
| 2-④ | Full Load 완료 확인 | Progress 100% |
| 2-⑤ | enable_migration=false, apply | IDC 리소스 삭제 |
| **Phase 3** | | |
| 3-① | terraform-azure apply | Azure VPN IP 취득 |
| 3-② | AWS main.tfvars 업데이트 | azure_vpn_gateway_ip |
| 3-③ | terraform apply | AWS Tunnel IP 취득 |
| 3-④ | Azure terraform.tfvars 업데이트 | aws_vpn_tunnel_ip |
| 3-⑤ | terraform-azure apply | 터널 UP |
| 3-⑥ | Aurora 재부팅 | binlog 활성화 |
| 3-⑦ | dms_replicator 계정 생성 | **수동** |
| 3-⑧ | CDC 태스크 시작 | **수동** |

---

## 인프라 삭제 순서

> AWS가 Azure에 의존(DMS, VPN)하므로 AWS를 먼저 내려야 함.

### ① DMS CDC 태스크 중지 ⚠️ 수동

ARN 확인:
```bash
aws dms describe-replication-tasks --query "ReplicationTasks[?ReplicationTaskIdentifier=='cdc-aurora-to-azure'].ReplicationTaskArn" --output text --region ap-northeast-2
```

중지:
```bash
aws dms stop-replication-task --replication-task-arn <ARN> --region ap-northeast-2
```

### ② AWS terraform destroy

```bash
cd terraform && terraform destroy -var-file=main.tfvars
```

> **AWS destroy가 완전히 완료된 후 Azure destroy 진행.** DMS/VPN이 Azure 리소스를 참조하고 있으므로 AWS 삭제가 끝나기 전에 Azure를 내리면 의존성 충돌 발생.

### ③ Azure terraform destroy

```bash
cd terraform-azure && terraform destroy -var-file=main.tfvars
```

### 삭제 요약

| 순서 | 작업 | 비고 |
|------|------|------|
| ① | DMS CDC 태스크 중지 | **수동**, destroy 전에 반드시 |
| ② | terraform destroy (AWS) | DMS, ECS, RDS, VPN 등 |
| ③ | terraform destroy (Azure) | VPN Gateway, MySQL 등 |
