# Azure CI/CD 작업 가이드

## 개요

인프라 파트가 Azure 기초 인프라(VNet, ACR, ACA Environment, MySQL, Blob, APIM, Static Web Apps)를
`terraform-azure/`에 구축해뒀다. 이 위에서 실제로 서비스가 동작하려면:

- **백엔드 5개 서비스**(auth/hotel/booking/review/support) 컨테이너 이미지를 ACR에 push하고 ACA에 배포
- **프론트엔드**를 빌드해서 Static Web Apps에 배포

까지 CI/CD 파이프라인으로 자동화하는 것이 이 파트의 목표다. AWS에서 CodePipeline + CodeBuild + buildspec.yml로
ECR push → ECS 배포를 자동화했던 것과 동일한 구조를, GitHub Actions로 재현한다고 보면 된다.
(전체 시나리오는 [infra-scenario.md](infra-scenario.md), 인프라 작업은 [azure-dr-infra-guide.md](azure-dr-infra-guide.md) 참고)

---

## AWS ↔ Azure 대응

| AWS | Azure | 비고 |
|---|---|---|
| CodePipeline + CodeBuild + buildspec.yml | GitHub Actions workflow | 빌드/배포 자동화 |
| ECR | Azure Container Registry (ACR) | 이미지 저장소 |
| ECS Fargate | Azure Container Apps (ACA) | 컨테이너 실행 환경 |
| Amplify (소스 연결 + 빌드) | Static Web Apps + GitHub Actions | 프론트엔드 배포 |
| IAM User + Access Key | Azure AD Service Principal | GitHub Actions → Azure 인증 |

---

## 해야 할 작업

### 1. Service Principal 발급 (Azure 인증)

GitHub Actions가 Azure 리소스(ACR, ACA, Static Web Apps)에 접근하려면 인증이 필요하다.
AWS에서 IAM User + Access Key를 발급해 CodePipeline에 연결했던 것과 동일한 역할.

```bash
az ad sp create-for-rbac \
  --name "github-actions-threetier-dr" \
  --role contributor \
  --scopes /subscriptions/<subscription_id>/resourceGroups/<resource_group_name> \
  --sdk-auth
```

- 출력된 JSON을 GitHub repo의 **Settings → Secrets and variables → Actions**에 `AZURE_CREDENTIALS`로 등록
- 권한 범위(role/scope)는 필요 이상으로 넓히지 말 것 — 보안 파트와 협의해 ACR push, ACA 배포, Static Web Apps 배포에 필요한 최소 권한으로 좁히는 걸 권장 (`AcrPush` 역할 등 세분화 가능)

### 2. ACR 이미지 태그/네이밍 규칙 확정 → 인프라 파트에 공유

이게 정해져야 인프라 파트가 ACA 서비스(`azurerm_container_app`) 5개 정의를 진행할 수 있다 (역의존 관계이므로 우선순위 높게 처리).

예시 규칙:
```
<acr_login_server>/<service_name>:<git_sha 또는 semver>
threetierdracr.azurecr.io/auth-service:abc1234
threetierdracr.azurecr.io/hotel-service:abc1234
...
```

- 서비스명은 AWS ECR의 리포지토리명과 통일하면 추후 비교/디버깅이 쉬움
- `latest` 태그보다는 `git sha` 또는 `semver` 기반 불변 태그 권장 (ACA 배포 시 어떤 빌드가 떠 있는지 추적 가능)

### 3. GitHub Actions 워크플로우 작성 — 백엔드 (ACR push → ACA 배포)

서비스 5개 각각에 대해 (또는 모노레포라면 경로 기반 매트릭스로):

```yaml
# .github/workflows/deploy-backend.yml (예시 골격)
name: Deploy Backend to ACA

on:
  push:
    branches: [main]
    paths: ['backend/**']

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [auth, hotel, booking, review, support]
    steps:
      - uses: actions/checkout@v4

      - name: Azure 로그인
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: ACR 로그인 & 이미지 빌드/푸시
        run: |
          az acr login --name <acr_name>
          docker build -t <acr_login_server>/${{ matrix.service }}-service:${{ github.sha }} ./backend/${{ matrix.service }}
          docker push <acr_login_server>/${{ matrix.service }}-service:${{ github.sha }}

      - name: ACA 배포
        uses: azure/container-apps-deploy-action@v1
        with:
          acrName: <acr_name>
          containerAppName: ${{ matrix.service }}-service
          resourceGroup: <resource_group_name>
          imageToDeploy: <acr_login_server>/${{ matrix.service }}-service:${{ github.sha }}
```

> AWS의 buildspec.yml에서 `docker build` → `docker push` → `aws ecs update-service`로 이어지던 흐름과 동일한 구조. `azure/container-apps-deploy-action`이 ECS의 `update-service` 역할을 한다.

### 4. GitHub Actions 워크플로우 작성 — 프론트엔드 (Static Web Apps 배포)

> 사용자가 직접 배포하기로 한 경우 이 항목은 생략 가능. 자동화한다면:

```yaml
# .github/workflows/deploy-frontend.yml (예시 골격)
name: Deploy Frontend to Static Web Apps

on:
  push:
    branches: [main]
    paths: ['frontend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          action: upload
          app_location: "/frontend"
          output_location: ""
```

- `AZURE_STATIC_WEB_APPS_API_TOKEN`은 `azurerm_static_web_app.frontend` 리소스의 배포 토큰(`api_key`) — 인프라 파트에 요청해서 받을 것
- 프론트의 `API_BASE` 설정은 환경변수/빌드 설정으로 분리해두면, 나중에 APIM 엔드포인트가 확정됐을 때 코드 수정 없이 교체 가능

### 5. 배포 테스트

- 워크플로우 실행 후 ACA 서비스별 엔드포인트(또는 APIM 게이트웨이)로 직접 호출해 정상 응답 확인
- Static Web Apps URL 접속 → 프론트가 백엔드 API와 통신하는지 확인
- 실패 시 GitHub Actions 로그 + Azure Monitor/Log Analytics(로그 파트가 연동) 함께 확인

---

## 주의할 점 / 협업 포인트

- **ACR 이미지 규칙은 빠르게 확정해서 공유** — 인프라 파트의 ACA 서비스 정의가 이걸 기다리고 있음 (병목 지점)
- **Service Principal 권한 범위는 보안 파트와 협의** — Contributor 같은 광범위한 역할보다 세분화된 역할 권장
- **민감정보(`AZURE_CREDENTIALS`, 배포 토큰 등)는 GitHub Secrets에만 저장** — 코드/워크플로우 파일에 직접 기재 금지
