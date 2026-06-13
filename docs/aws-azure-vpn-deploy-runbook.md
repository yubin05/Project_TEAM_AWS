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
cd terraform-azure && terraform apply -var-file=main.tfvars
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

> Phase 1 최초 apply 시 `azure_vpn_gateway_ip`에 임시/이전 IP로 이미 customer gateway/vpn connection이 생성된 상태.
> AWS customer gateway는 `ip_address` 변경이 불가능(immutable)하므로, 새 Azure IP로 갱신하려면
> vpn_connection → customer_gateway 순으로 삭제 후 재생성해야 함 → `-replace`로 명시.

```bash
cd terraform && terraform apply -var-file=main.tfvars -replace="aws_vpn_connection.azure[0]" -replace="aws_customer_gateway.azure[0]"
```

output에서 확인:
```
vpn_azure_tunnel1_address = "3.35.57.106"  # 예시
```

### ④ Azure tfvars 업데이트

`terraform-azure/main.tfvars`:
```hcl
aws_vpn_tunnel_ip = "위에서 나온 IP"
```

### ⑤ Azure apply 재실행 (터널 UP)

```bash
cd terraform-azure && terraform apply -var-file=main.tfvars
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

## Phase 4 — Route53 DR Failover (www.vundle34.cloud)

> Primary = AWS Amplify(CloudFront), Secondary = Azure Static Web App.
> Gabia에서 `vundle34.cloud` 전체 NS를 Route53으로 위임 완료된 상태가 전제.

### ① AWS apply (1차 — 도메인 연결 + 헬스체크)

```bash
cd terraform && terraform apply -var-file=main.tfvars -target=aws_amplify_domain_association.frontend -target=aws_route53_health_check.aws_frontend
```

> ACM 인증서는 Amplify가 같은 계정의 Route53 zone을 감지해 **자동으로 발급/검증 CNAME까지 생성**한다
> (`aws_route53_record.amplify_cert_validation` 같은 별도 리소스 불필요).
> 이 과정에서 Amplify가 `www` CNAME(→ CloudFront, failover 정책 없는 일반 레코드)도 자동 생성한다.

도메인 상태 확인 (`AVAILABLE`이 될 때까지 15~30분, 최대 1시간 대기):

```bash
aws amplify get-domain-association --app-id d21lqy32bq1s4y --domain-name vundle34.cloud --region ap-northeast-2 --query "domainAssociation.domainStatus"
```

### ② Amplify가 자동 생성한 www CNAME 삭제

`AVAILABLE` 확인 후, failover 레코드 쌍(`www_primary`/`www_secondary`)과 이름+타입이 겹쳐 충돌하므로
Amplify가 만든 일반 `www` CNAME을 먼저 삭제해야 한다 (zone_id는 `aws_route53_zone.dr` 출력 참고):

```bash
aws route53 change-resource-record-sets --hosted-zone-id <ZONE_ID> --change-batch file://delete-www-cname.json
```

`delete-www-cname.json` 예시:
```json
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": {
      "Name": "www.vundle34.cloud.",
      "Type": "CNAME",
      "TTL": 500,
      "ResourceRecords": [{ "Value": "<amplify get-domain-association의 sub_domain dns_record 값>" }]
    }
  }]
}
```

### ③ AWS apply (2차 — failover CNAME 쌍)

```bash
terraform apply -var-file=main.tfvars -target=aws_route53_record.www_primary -target=aws_route53_record.www_secondary
```

### ④ Azure Static Web App 커스텀 도메인 (HTTPS)

`www.vundle34.cloud`이 Azure를 가리키고 있는 동안(CNAME-delegation 검증) 적용해야 한다:

```bash
cd terraform-azure && terraform apply -target=azurerm_static_web_app_custom_domain.frontend
```

인증서 발급 확인 (`status: Ready`):
```bash
az staticwebapp hostname list --name threetier-dr-frontend --resource-group threetier-dr-rg
```

### ⑤ CORS — www.vundle34.cloud 추가

- AWS API Gateway(`terraform/apigateway.tf`): `allow_origins`에 명시 origin 화이트리스트로 관리 (`www.vundle34.cloud`, Amplify 기본 도메인, Azure Static Web App, localhost)
- Azure APIM(`terraform-azure/azure-apim.tf`): `<allowed-origins>`에 `https://www.vundle34.cloud` 추가

```bash
cd terraform && terraform apply -var-file=main.tfvars -target=aws_apigatewayv2_api.main
cd terraform-azure && terraform apply -target=azurerm_api_management_api_policy.main
```

### ⑥ Failover 동작 테스트

> ECS/RDS를 멈춰도 헬스체크 대상(Amplify 정적 사이트)은 계속 정상이라 `aws-pause.cmd`로는 failover가 트리거되지 않는다.
> 대신 헬스체크의 `inverted` 옵션으로 "정상인데 비정상처럼" 보이게 만들어 안전하게 테스트한다.

헬스체크 ID 확인:
```bash
aws route53 list-health-checks --query "HealthChecks[?HealthCheckConfig.FullyQualifiedDomainName=='main.d21lqy32bq1s4y.amplifyapp.com'].Id" --output text
```

장애 시뮬레이션:
```bash
aws route53 update-health-check --health-check-id <ID> --inverted
```

1.5~2분(failure_threshold=3 × interval=30s) + DNS TTL(60s) 대기 후:
```bash
nslookup www.vundle34.cloud
```
→ `calm-plant-04a6be700.7.azurestaticapps.net` (Azure)로 전환되면 정상.

원복:
```bash
aws route53 update-health-check --health-check-id <ID> --no-inverted
```

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
| 3-④ | Azure main.tfvars 업데이트 | aws_vpn_tunnel_ip |
| 3-⑤ | terraform-azure apply | 터널 UP |
| 3-⑥ | Aurora 재부팅 | binlog 활성화 |
| 3-⑦ | dms_replicator 계정 생성 | **수동** |
| 3-⑧ | CDC 태스크 시작 | **수동** |
| **Phase 4** | | |
| 4-① | AWS apply (1차) | 도메인 연결 + ACM 인증서 자동 발급 |
| 4-② | Amplify 자동생성 www CNAME 삭제 | **수동** |
| 4-③ | AWS apply (2차) | failover CNAME 쌍 생성 |
| 4-④ | Azure Static Web App 커스텀 도메인 apply | 무료 인증서 자동 발급 |
| 4-⑤ | CORS origin 추가 (AWS/Azure) | www.vundle34.cloud |
| 4-⑥ | Failover 테스트 (헬스체크 inverted) | 테스트 후 원복 필수 |

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
