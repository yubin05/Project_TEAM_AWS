# Azure DR 인프라 작업 가이드

## 개요

AWS에서 이미 구축한 ECR / ECS Fargate / ALB / Aurora / Amplify / CodePipeline 구조를,
멀티클라우드 재해복구(DR) 시나리오에 따라 Azure 쪽에 대응하는 형태로 재현한다.
정상 시에는 AWS·Azure가 동시에 트래픽을 처리하는 Active-Active 구성이며,
AWS 장애 시 Route 53 헬스체크 → Azure Traffic Manager로 자동 전환되는 것이 최종 목표.
(전체 시나리오/요구사항은 [infra-scenario.md](infra-scenario.md) 참고)

---

## AWS ↔ Azure 대응표

| AWS (이미 구축) | Azure (이번에 구축) | 구분 | 담당 파트 |
|---|---|---|---|
| VPC | Azure Virtual Network | 필수 | 인프라 |
| ECR | Azure Container Registry (ACR) | 필수 | 인프라 |
| ECS Fargate | Azure Container Apps (ACA) | 필수 | 인프라 |
| API Gateway | Azure API Management (APIM) | 필수 | 인프라 |
| Amplify | Azure Static Web Apps | 필수 | 인프라 |
| Route 53 | Azure Traffic Manager | 필수 | 인프라 |
| Aurora MySQL | Azure Database for MySQL | 권장 | 인프라 |
| S3 | Azure Blob Storage | 권장 | 인프라 |
| CodePipeline + CodeBuild | GitHub Actions | 필수 | CI/CD |
| IAM | Azure AD(Entra ID) + RBAC | 필수 | 보안 |
| Security Group | Network Security Group (NSG) | 필수 | 보안 |
| Secrets Manager | Azure Key Vault | 권장 | 보안 |
| CloudWatch | Azure Monitor + Log Analytics | 필수 | 로그 |
| DMS | AWS DMS → Azure DB (단방향 CDC 복제) | 필수 | 로그 |

> ACR/ACA는 "리소스"만 만들면 되고, 그 위에서 도는 빌드/배포 자동화(GitHub Actions)는 CI/CD 파트 담당.
> AWS에서 인프라 파트가 ECR·ECS를 만들고 CodePipeline+buildspec.yml로 CI/CD 파트가 자동화했던 것과 동일한 분담 구조.

---

## 전체 구축 순서 (의존성 기준)

```
1단계: [인프라] VNet/Subnet 설계        ← 모든 것의 기반, 가장 먼저
        ↕
       [보안]   Azure AD/RBAC 계정 + NSG 설계
2단계: [인프라] ACR + ACA 환경(Environment) + Azure DB for MySQL + Static Web Apps
3단계: [CI/CD] GitHub Actions 워크플로우 (ACR push → ACA 배포)
4단계: [CI/CD] 배포 테스트              [로그] Monitor/Log Analytics + DMS 복제 연동
5단계: [인프라] APIM + Traffic Manager + Route 53 가중치 라우팅   ← 모든 엔드포인트가 떠 있어야 함, 항상 마지막
6단계: 전체 DR 시나리오 테스트 (AWS 장애 시뮬레이션 → Azure 전환 + DB 승격 확인)
```

> 네트워크(VNet/Subnet)가 가장 먼저인 이유: DB의 Private Endpoint, ACA의 VNet 연동이 전부 그 위에 올라가기 때문. Traffic Manager/Route 53은 양쪽 클라우드 엔드포인트가 모두 준비된 후에야 헬스체크·라우팅 테스트가 가능하므로 항상 마지막.

---

## 파트별 작업 정리

### 인프라 파트

의존성 순서상 아래 순서로 진행:

1. **Azure Virtual Network** — VNet, Subnet 설계 (AWS VPC 구조에 대응) — *최우선, 빠지면 안 됨*
2. **Azure Container Registry (ACR)** — 이미지 저장소, RBAC은 보안 파트와 협의
3. **Azure Container Apps (ACA) 환경(Environment)** — 환경(Environment) + VNet 연동까지
   - 서비스 5개(`azurerm_container_app`) 정의는 ACR 이미지 태그/네이밍 규칙이 CI/CD 파트에서 정해진 뒤 진행 — 먼저 만들면 재작업 가능성 높음
4. **Azure Database for MySQL** — 평소엔 Aurora(원본) → Azure 단방향 복제(DMS CDC)로 읽기 전용 동기화, AWS 장애 시 쓰기 가능한 Primary로 승격(promote)되는 페일오버 타겟. 네트워크(서브넷, Private Endpoint 여부)가 먼저 정해져야 하므로 1번 이후 진행
5. **Azure Static Web Apps** — 프론트엔드 이중화. 다른 항목과 의존성 없어 병렬 가능
6. **Azure API Management (APIM)** — AWS API Gateway 대응. Active-Active 구조에서 Route 53/Traffic Manager가 클라우드당 단일 엔드포인트를 기준으로 라우팅하므로, ACA 서비스별 개별 ingress 대신 통합 진입점 역할
7. **Azure Traffic Manager + Route 53 가중치 라우팅 추가** — 모든 엔드포인트(APIM, Static Web Apps, DB)가 준비된 후 마지막에 진행

### CI/CD 파트

- **GitHub Actions 워크플로우 구성** — "ACR로 이미지 push → ACA에 배포" 자동화. AWS에서 CodePipeline+buildspec.yml이 ECR/ECS를 대상으로 했던 것과 동일한 구조
- **Service Principal 발급** — GitHub Actions → Azure 인증용 (AWS의 IAM User+Access Key에 대응), 보안 파트와 협의해 권한 범위 설정
- **ACR 이미지 태그/네이밍 규칙 확정** — 이게 정해져야 인프라 파트가 ACA 서비스 5개 정의를 진행할 수 있음 (역의존성 — 빠르게 확정해서 공유 필요)
- **배포 테스트** — 워크플로우로 실제 배포까지 검증

### 보안 파트

- **Azure AD(Entra ID) 팀 계정 생성 + RBAC 역할 할당** — 다른 파트가 Azure 리소스에 접근하려면 선행되어야 함 (AWS IAM User/Role에 대응)
- **NSG(Network Security Group) 규칙 설계** — VNet/Subnet 구조가 정해져야 규칙을 짤 수 있으므로 인프라 파트와 네트워크 구조를 먼저 공유받고 진행
  - DB 서브넷: ACA 서브넷 → MySQL 포트(3306)만 허용, 그 외 인바운드 차단
  - DMS 복제 인스턴스 ↔ Azure DB 간 네트워크 경로(퍼블릭 엔드포인트+TLS vs Private Endpoint/VPN)도 함께 결정
- **ACR RBAC 정책** — Push/Pull 권한을 CI/CD 파트의 Service Principal에 할당
- **Azure Key Vault** — DB 비밀번호, API 키 등 민감정보 관리 (AWS Secrets Manager에 대응, 권장)

### 로그 파트

- **Azure Monitor + Log Analytics 연동** — ACA, DB 등 리소스 로그/메트릭 수집 (AWS CloudWatch에 대응)
- **AWS DMS ongoing replication(CDC) 설정** — Aurora → Azure MySQL 단방향 복제 구성, RPO 5분 요구사항 충족 여부 검증
  - DMS 복제 인스턴스의 네트워크 경로는 보안 파트와 사전 조율 필요
- **장애 시나리오용 알림/대시보드** — Route 53 헬스체크 실패, DB 승격 등의 이벤트를 모니터링할 수 있도록 구성

---

## Terraform 모듈 분리 제안 (인프라 파트)

| 파일 | 내용 | 의존성 |
|---|---|---|
| `azure-network.tf` | VNet, Subnet | 없음 — 최우선 |
| `azure-nsg.tf` | NSG, 서브넷 연동 | 네트워크 구조 확정 후 (보안 파트와 협의) |
| `azure-acr.tf` | Container Registry | 없음 — 병렬 가능 |
| `azure-aca.tf` | Container Apps 환경 + 서비스 5개 | ACR 이미지 태그 규칙 필요 (CI/CD와 연계) |
| `azure-static-webapp.tf` | 프론트엔드 이중화 | 없음 — 병렬 가능 |
| `azure-mysql.tf` | DB 단방향 복제 타겟 | 네트워크 + 보안(Private Endpoint)과 연계 |
| `azure-blob.tf` | S3 ↔ Blob 동기화 | 없음 — 병렬 가능 |
| `azure-apim.tf` | API Management (API Gateway 대응) | ACA 서비스 엔드포인트 필요 |
| `azure-traffic-manager.tf` + Route 53 가중치 추가 | 헬스체크/장애 전환 | **모든 엔드포인트가 떠 있어야 함 → 항상 마지막** |

---

## 다른 파트와 맞물리는 지점 (미리 알아두면 좋은 것)

- **ACR/ACA ↔ CI/CD**: GitHub Actions 워크플로우가 "ACR로 이미지 push → ACA에 배포"하는 대상이 됨. 이미지 태그/네이밍 규칙은 CI/CD가 정하고 인프라가 그에 맞춰 ACA 서비스를 정의하는 역의존 관계이므로 빠른 협의 필요.
- **VNet/Subnet ↔ 보안**: NSG 규칙 설계의 전제 조건. 네트워크 구조를 먼저 공유해야 NSG·Private Endpoint 작업이 진행 가능.
- **DB 복제(Aurora → Azure MySQL) ↔ 로그/보안**: AWS DMS의 ongoing replication(CDC)으로 단방향 복제 (RPO 5분 요구사항에 부합). 평소엔 Aurora가 원본, Azure DB는 읽기 전용 복제본 — 양방향 다중 마스터는 충돌 해결이 복잡해 지양. **AWS 장애 시 Azure DB를 쓰기 가능한 Primary로 승격(promote)** 하는 페일오버 절차가 필요하며, 이는 전체 DR 시나리오 테스트에서 함께 검증 (복구 후 failback 시에는 Azure→AWS 역방향 재동기화도 필요). DMS 복제 인스턴스 ↔ Azure DB 간 네트워크 경로는 보안 파트와 사전 조율 필요.
- **APIM/Traffic Manager/Route 53 ↔ 모든 파트**: 양쪽 클라우드의 모든 엔드포인트(ACA 서비스, DB, 정적 사이트)가 준비된 후에야 헬스체크/가중치 라우팅 테스트가 가능하므로, 항상 마지막 단계에 배치.

---

## 체크리스트

**인프라**
- [ ] VNet + Subnet 생성 (AWS VPC 구조 참고)
- [ ] ACR 생성
- [ ] ACA 환경(Environment) + VNet 연동
- [ ] ACA 서비스 5개 정의 (CI/CD의 이미지 태그 규칙 확정 후)
- [ ] Azure Database for MySQL 생성 (네트워크 경로는 보안 파트와 합의)
- [ ] Azure Static Web Apps 생성
- [ ] Azure API Management 구성
- [ ] Azure Traffic Manager + Route 53 가중치 라우팅 연동

**CI/CD**
- [ ] Service Principal 발급 (GitHub Actions ↔ Azure 인증)
- [ ] ACR 이미지 태그/네이밍 규칙 확정 → 인프라 파트에 공유
- [ ] GitHub Actions 워크플로우 작성 (ACR push → ACA 배포)
- [ ] 배포 테스트

**보안**
- [ ] Azure AD(Entra ID) 팀 계정 생성 + RBAC 역할 할당
- [ ] NSG 규칙 설계 및 적용 (네트워크 구조 공유받은 후)
- [ ] ACR RBAC 정책 (Push/Pull 권한을 Service Principal에 할당)
- [ ] Azure Key Vault 구성 (DB 비밀번호, API 키 관리)

**로그**
- [ ] Azure Monitor + Log Analytics 연동
- [ ] AWS DMS ongoing replication(CDC) 설정 — Aurora → Azure MySQL
- [ ] 장애 감지/DB 승격 이벤트 알림·대시보드 구성

**전체**
- [ ] 전체 DR 시나리오 테스트 (AWS 장애 시뮬레이션 → Azure 전환 + DB 승격/failback 확인)

---

## 트러블슈팅

### `MissingSubscriptionRegistration` 오류 (Resource Provider 미등록)

`terraform apply` 시 아래와 같이 `Microsoft.App`, `Microsoft.ContainerRegistry`, `Microsoft.ApiManagement` 등의
namespace가 등록되지 않았다는 409 오류가 날 수 있다.

```
Error: ... unexpected status 409 (409 Conflict) with error: MissingSubscriptionRegistration:
The subscription is not registered to use namespace 'Microsoft.App'.
```

**원인**: `main.tf`의 `provider "azurerm"`에 `skip_provider_registration = true`를 설정해뒀기 때문이다.
(Free Trial류 구독에서 azurerm이 ~30개 이상의 전체 provider namespace를 자동 등록하려다 멈추는 문제가 있어 비활성화함)

**해결**: 이 프로젝트가 실제로 쓰는 provider만 수동으로 등록한다.

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.ApiManagement

# 등록 상태 확인 — 각각 "Registered"가 나오면 완료 (몇 분 걸릴 수 있음, "Registering"이면 잠시 후 재확인)
az provider show --namespace Microsoft.App --query registrationState -o tsv
az provider show --namespace Microsoft.ContainerRegistry --query registrationState -o tsv
az provider show --namespace Microsoft.ApiManagement --query registrationState -o tsv
```

전부 `Registered`가 된 후 `terraform apply`를 다시 실행하면 된다.

> 자동 등록(`skip_provider_registration = false`)으로 바꿔도 되지만, 안 쓰는 provider까지 전부 등록하려다
> 다시 멈출 위험이 있어 필요한 것만 수동 등록하는 쪽을 권장한다.

### `StorageAccountAlreadyTaken` 오류 (Storage Account 이름 전역 충돌)

Storage Account 이름은 **Azure 전체에서 유일**해야 한다. `project_prefix`만 붙인 이름(예: `threetierdruploads`)은
이미 다른 누군가가 선점했을 수 있다 — 이 경우 [azure-blob.tf](../terraform-azure/azure-blob.tf)처럼 식별자를
추가해 유일한 이름으로 바꿔야 한다 (24자 제한, 소문자/숫자만 가능).

### `ServiceAlreadyExistsInSoftDeletedState` 오류 (APIM 소프트 삭제 충돌)

```
Error: ... 409 Conflict ... ServiceAlreadyExistsInSoftDeletedState:
Api service threetier-dr-apim was soft-deleted. In order to create the new service
with the same name, you have to either undelete the service or purge it.
```

**원인**: API Management는 삭제해도 즉시 사라지지 않고 **소프트 삭제(soft-delete)** 상태로 남아, 같은 이름으로
재생성하려 하면 위 오류가 난다. (Key Vault의 소프트 삭제와 동일한 개념)

**해결**: CLI로 완전히 제거(purge)한 뒤 다시 생성한다.

```bash
# 소프트 삭제된 APIM 인스턴스 목록 확인
az apim deletedservice list -o table

# 완전 삭제(purge) — 같은 이름으로 재생성 가능해짐
az apim deletedservice purge --service-name threetier-dr-apim --location koreacentral
```

> ⚠️ **`terraform destroy`로 인프라를 내릴 때마다 반복될 수 있는 문제다.** APIM을 삭제하면 그때마다
> 소프트 삭제 상태로 남으므로, 같은 이름으로 다시 `apply`하기 전에 매번 purge를 거쳐야 한다.
> DR 인프라를 반복적으로 올렸다 내렸다 하는 테스트 워크플로우라면, 아래 순서를 표준 절차로 삼을 것:
>
> ```bash
> terraform destroy -var-file=main.tfvars
> az apim deletedservice purge --service-name threetier-dr-apim --location koreacentral
> terraform apply -var-file=main.tfvars
> ```
