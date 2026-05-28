# AWS 인프라 구성

## 공통 아키텍처 (ECS / EKS 공통)

> 컨테이너 오케스트레이션 레이어만 다르고 나머지 AWS 서비스는 동일합니다.

```
사용자
  │
  ├── Amplify (프론트엔드 CDN + 자동 배포)
  │
  └── WAF
        ↓
   API Gateway (HTTP API)
   ├── Cognito JWT Authorizer (인증 필요 라우트)
   ├── /auth/*       → auth-service
   ├── /hotels/*     → hotel-service
   ├── /bookings/*   → booking-service
   └── /reviews/*    → review-service
        ↓ (VPC Link)
       ALB (internal)
        ↓
   [ ECS Fargate  또는  EKS ]  ← 이 부분만 다름
        ↓
   RDS MySQL (서비스별 독립 DB)
   DynamoDB (캐시)
   S3 (이미지/영상/로그 보관)
   Bedrock (AI 추천)

   SQS booking-queue → Lambda ──→ SES (예약 확정 이메일)
   S3 업로드 이벤트  → Lambda ──→ S3 (썸네일 리사이즈)
   Cognito 회원가입  → Lambda ──→ RDS auth_db (유저 프로필 초기화)
```

---

## Option A — ECS Fargate

> AWS 네이티브 방식. 설정 간단, 운영 오버헤드 낮음.

### 아키텍처

```
ALB (internal)
      ↓ Target Group (서비스별)
ECS Fargate
├── auth-service    :3001
├── hotel-service   :3002
├── booking-service :3003
└── review-service  :3004
```

### 구성 요소

| 항목 | ECS 방식 |
|---|---|
| 컨테이너 정의 | Task Definition (JSON) |
| 실행 단위 | Task |
| 서비스 관리 | ECS Service |
| ALB 연동 | Target Group 자동 등록 |
| 배포 | CodeDeploy (Blue/Green or Rolling) |
| 스케일링 | ECS Auto Scaling |
| IAM 권한 | Task Role |

### CI/CD (CodePipeline)

```
GitHub push (backend/**)
    → CodePipeline 감지
    → CodeBuild: docker build → ECR push
    → CodeDeploy: Task Definition 업데이트 → ECS Service 재배포
```

**경로 필터 설정** (CodePipeline V2):
```yaml
Triggers:
  - ProviderType: CodeStarSourceConnection
    GitConfiguration:
      Push:
        - FilePaths:
            Includes:
              - backend/**
            Excludes:
              - frontend/**
              - docs/**
              - "*.md"
```

> **주의**: 경로 필터는 CodePipeline **V2** 에서만 지원됩니다.

### 보안 구성

```
인터넷
  └── WAF
        └── API Gateway (Cognito JWT 검증)
              └── VPC Link
                    └── ALB internal (VPC Link에서만 인바운드)
                          └── ECS (ALB에서만 인바운드)
                                └── RDS (ECS에서만 3306)
```

---

## Option B — EKS

> Kubernetes 방식. 운영 오버헤드 높지만 K8s 생태계 활용 가능.

### 아키텍처

```
ALB (internal)  ← AWS Load Balancer Controller가 관리
      ↓ Ingress 규칙
EKS Cluster
└── Namespace: travel-app
    ├── Deployment: auth-service    (Pod × N)
    ├── Deployment: hotel-service   (Pod × N)
    ├── Deployment: booking-service (Pod × N)
    └── Deployment: review-service  (Pod × N)
```

### 구성 요소

| 항목 | EKS 방식 |
|---|---|
| 컨테이너 정의 | deployment.yaml |
| 실행 단위 | Pod |
| 서비스 관리 | K8s Service |
| ALB 연동 | AWS Load Balancer Controller + Ingress |
| 배포 | kubectl apply / Helm / ArgoCD |
| 스케일링 | HPA (Horizontal Pod Autoscaler) |
| IAM 권한 | IRSA (IAM Roles for Service Accounts) |

### K8s 매니페스트 구조

```
k8s/
├── namespace.yaml
├── auth-service/
│   ├── deployment.yaml
│   └── service.yaml
├── hotel-service/
│   ├── deployment.yaml
│   └── service.yaml
├── booking-service/
│   ├── deployment.yaml
│   └── service.yaml
├── review-service/
│   ├── deployment.yaml
│   └── service.yaml
└── ingress.yaml          ← ALB Ingress (경로 라우팅)
```

### CI/CD (CodePipeline + kubectl)

```
GitHub push (backend/**)
    → CodePipeline 감지
    → CodeBuild: docker build → ECR push → kubectl apply
    → EKS: 새 이미지로 Rolling Update
```

### 보안 구성

```
인터넷
  └── WAF
        └── API Gateway (Cognito JWT 검증)
              └── VPC Link
                    └── ALB internal (AWS LB Controller 관리)
                          └── EKS Pod (ALB에서만 인바운드)
                                └── RDS (EKS Node SG에서만 3306)
```

---

## ECS vs EKS 비교

| 항목 | ECS Fargate | EKS |
|---|---|---|
| 설정 난이도 | 낮음 | 높음 |
| 운영 오버헤드 | 낮음 | 높음 |
| AWS 네이티브 | ✅ | 부분적 |
| K8s 이식성 | ❌ | ✅ |
| 클러스터 비용 | 없음 | $0.10/시간 추가 |
| 배포 방식 | CodeDeploy | kubectl / Helm / ArgoCD |
| 스케일링 | ECS Auto Scaling | HPA |
| 학습 목적 | AWS 집중 | K8s 생태계 |
| **권장 상황** | 빠른 배포, 운영 단순화 | K8s 경험, 멀티클라우드 고려 |

---

## 공통 AWS 서비스 역할

| 서비스 | 역할 |
|---|---|
| **Amplify** | 프론트엔드 정적 파일 호스팅 + GitHub 자동 배포 |
| **WAF** | SQL Injection, XSS 차단 / Rate Limiting |
| **API Gateway** | HTTP API 엔드포인트 + Cognito JWT Authorizer + VPC Link |
| **ALB** | VPC 내부 트래픽 로드밸런싱 (internal) |
| **ECR** | 서비스별 Docker 이미지 저장소 |
| **CodePipeline** | 백엔드 CI/CD 자동화 파이프라인 |
| **CodeBuild** | Docker 이미지 빌드 + ECR push |
| **Cognito** | 회원가입/로그인 + JWT 토큰 발급 |
| **RDS MySQL** | 서비스별 독립 DB (auth/hotel/booking/review) |
| **DynamoDB** | 호텔 검색 캐시 |
| **SQS** | 서비스 간 비동기 메시지 큐 (rating-queue, booking-queue) |
| **SES** | 예약 확정 이메일 발송 (Lambda 통해 호출) |
| **S3** | 호텔 이미지 / 소개 영상 / 로그 장기 보관 |
| **Bedrock** | Claude 3 Haiku 기반 AI 숙소 추천 |
| **Lambda** | SQS 트리거 이메일 / Cognito 후처리 / S3 이미지 리사이즈 |
| **Secrets Manager** | DB 비밀번호, JWT 시크릿 등 민감 정보 관리 |
| **CloudWatch** | 서비스별 실시간 로그 수집 및 알람 |
| **Athena** | S3 로그 SQL 분석 |
| **VPC + Security Group** | 서비스 간 네트워크 격리 |
| **DMS** | MySQL EC2 → RDS 무중단 데이터 이전 |

---

## CI/CD 트리거 분리 (공통)

> 모노레포 구조이므로 경로 필터로 불필요한 빌드 방지

| push 경로 | Amplify | CodePipeline |
|---|---|---|
| `frontend/**` | ✅ 빌드 | ❌ 스킵 |
| `backend/**` | ❌ 스킵 | ✅ 빌드 |
| `docs/**`, `*.md` | ❌ 스킵 | ❌ 스킵 |

---

## Lambda 구성

| 트리거 | Lambda 역할 | 연결 서비스 |
|---|---|---|
| SQS `booking-queue` | 예약 확정 이메일 발송 | → SES |
| S3 업로드 이벤트 | 호텔 이미지 썸네일 리사이즈 | → S3 (처리본 저장) |
| Cognito Post Confirmation | 회원가입 후 유저 프로필 초기화 | → RDS `auth_db` |

### 흐름 상세

#### 1. 예약 이메일 (SQS → Lambda → SES)

```
booking-service
    → SQS (booking-queue) 메시지 발행
        → Lambda 트리거
            → SES 이메일 발송
```

#### 2. 이미지 리사이즈 (S3 → Lambda → S3)

```
hotel-service
    → S3 원본 이미지 업로드 (hotels/original/)
        → S3 Event 트리거 → Lambda
            → Sharp 라이브러리로 썸네일 생성
                → S3 저장 (hotels/thumbnail/)
```

#### 3. Cognito 회원가입 후처리 (Cognito → Lambda → RDS)

```
사용자 회원가입 → Cognito 처리
    → Post Confirmation 트리거 → Lambda
        → auth_db.users 테이블에 초기 레코드 INSERT
```

---

## API Gateway 구성

### 라우팅 규칙

| 경로 | 대상 서비스 | Cognito 인증 |
|---|---|---|
| `ANY /auth/register` | auth-service | ❌ (공개) |
| `ANY /auth/login` | auth-service | ❌ (공개) |
| `ANY /auth/{proxy+}` | auth-service | ✅ |
| `ANY /hotels/{proxy+}` | hotel-service | ✅ (조회는 선택) |
| `ANY /bookings/{proxy+}` | booking-service | ✅ |
| `ANY /reviews/{proxy+}` | review-service | ✅ |

### API Gateway vs ALB 역할 분담

| 역할 | API Gateway | ALB |
|---|---|---|
| 외부 엔드포인트 | ✅ (퍼블릭) | ❌ (internal 전용) |
| Cognito 인증 | ✅ JWT Authorizer | ❌ |
| Rate Limiting | ✅ | ❌ |
| WAF 연결 | ✅ | ❌ |
| 경로 라우팅 | ✅ (서비스 단위) | ✅ (세부 경로) |
| 헬스체크 | ❌ | ✅ |

---

## 로그 분석 파이프라인 (CloudWatch → S3 → Athena)

```
컨테이너 로그 (ECS or EKS)
      ↓
  CloudWatch Logs (실시간 수집 / 알람)
      ↓ (Export)
      S3 (로그 장기 보관, 저비용)
      ↓
   Athena (SQL로 로그 분석)
```

```sql
-- 서비스별 에러 집계
SELECT service, COUNT(*) AS error_count
FROM logs
WHERE level = 'error'
GROUP BY service ORDER BY error_count DESC;

-- 시간대별 API 호출량
SELECT endpoint, COUNT(*) AS calls
FROM logs
WHERE timestamp BETWEEN '2024-01-01' AND '2024-01-02'
GROUP BY endpoint;
```

---

## MySQL EC2 → RDS 마이그레이션 (DMS)

> 기존 MySQL EC2 데이터를 무중단으로 RDS에 이전합니다.

```
MySQL EC2 (Source)
      ↓
  DMS 복제 인스턴스
  ├── Full Load : 기존 데이터 전체 복사
  └── CDC       : 이전 중 변경사항 실시간 동기화
      ↓
  RDS MySQL (Target)
      ↓
  서비스 DB_HOST → RDS 엔드포인트로 전환
```

| 항목 | MySQL EC2 | RDS |
|---|---|---|
| 백업 | 수동 | 자동 (최대 35일) |
| 장애 복구 | 직접 대응 | Multi-AZ 자동 Failover |
| 패치/업그레이드 | 직접 | AWS 관리 |
| 모니터링 | 직접 설정 | CloudWatch 자동 연동 |

> DMS 복제 인스턴스는 이전 완료 후 즉시 삭제 (실행 시간만큼 과금)
