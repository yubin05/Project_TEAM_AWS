# AI 여행 예약 플랫폼 — Project TEAM AWS

야놀자 스타일의 여행 및 숙박 예약 플랫폼.  
**로컬 Docker 환경**과 **AWS 클라우드 환경** 두 가지 모드로 실행 가능합니다.

---

## 빠른 시작 (로컬 테스트)

Docker와 Docker Compose만 있으면 AWS 계정 없이 바로 실행됩니다.

```bash
# 1. Clone
git clone https://github.com/yubin05/Project_TEAM_AWS.git
cd Project_TEAM_AWS

# 2. 전체 스택 실행 (Frontend + Backend + MySQL + DynamoDB Local)
docker compose -f docker-compose.local.yml up --build

# 3. 시드 데이터 입력 (최초 1회, 새 터미널에서)
docker compose -f docker-compose.local.yml exec backend npm run seed

# 4. 접속
# 프론트엔드:  http://localhost
# API:         http://localhost:3000/api
# 헬스체크:    http://localhost:3000/health
```

### 로컬 환경 전제 조건

```bash
# Ubuntu 기준
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo systemctl start docker
sudo usermod -aG docker $USER   # 재로그인 후 sudo 없이 사용 가능
```

---

## 실행 모드

`APP_MODE` 환경변수로 두 가지 모드를 전환합니다.

| 항목 | `local` (기본값) | `aws` |
|------|-----------------|-------|
| 인증 | 자체 JWT | AWS Cognito |
| 데이터베이스 | MySQL 컨테이너 | RDS MySQL |
| NoSQL | DynamoDB Local | DynamoDB |
| 번역 | Mock (원본 반환) | Amazon Translate |
| 자격증명 | 더미 키 | IAM Role 자동 처리 |

```bash
# 로컬 모드 실행
docker compose -f docker-compose.local.yml up --build

# AWS 연동 모드 실행 (.env.aws 파일 먼저 작성)
cp backend/.env.aws.example backend/.env.aws
# .env.aws 에 RDS endpoint, Cognito ID 등 실제 값 입력
docker compose -f docker-compose.aws.yml up --build
```

---

## 테스트 계정

| 역할 | 이메일 | 비밀번호 |
|------|--------|---------|
| 관리자 | admin@travel.com | password123 |
| 호스트 | host@travel.com | password123 |
| 일반 | user@travel.com | password123 |

---

## 프로젝트 구조

```
Project_TEAM_AWS/
├── docker-compose.local.yml        로컬 테스트 (AWS 불필요)
├── docker-compose.aws.yml          AWS 연동 버전
│
├── frontend/
│   ├── Dockerfile                  Nginx 이미지
│   ├── nginx.conf                  SPA 라우팅 + /api 프록시
│   └── public/
│       ├── index.html
│       ├── css/style.css
│       └── js/app.js
│
└── backend/
    ├── Dockerfile                  멀티스테이지 빌드
    ├── .env.local                  로컬 환경변수 (커밋됨)
    ├── .env.aws.example            AWS 환경변수 템플릿
    └── src/
        ├── app.ts                  서버 진입점
        ├── config/
        │   └── index.ts            APP_MODE 기반 환경 설정
        ├── controllers/
        │   ├── authController.ts
        │   ├── hotelController.ts
        │   ├── bookingController.ts
        │   └── reviewController.ts
        ├── middleware/
        │   └── auth.ts             로컬 JWT / Cognito 분기
        ├── models/
        │   ├── pool.ts             MySQL2 커넥션 풀
        │   ├── database.ts         MySQL 스키마 초기화
        │   └── dynamo.ts           DynamoDB 클라이언트 + 번역 캐시
        ├── services/
        │   └── translateService.ts Amazon Translate + DynamoDB 캐시
        ├── routes/
        │   └── index.ts
        ├── types/
        │   └── index.ts
        └── seed.ts                 시드 데이터
```

---

## API 엔드포인트

### 인증
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | /api/auth/register | 회원가입 |
| POST | /api/auth/login | 로그인 |
| GET | /api/auth/profile | 프로필 조회 |
| PUT | /api/auth/profile | 프로필 수정 |
| PUT | /api/auth/password | 비밀번호 변경 |

### 숙소
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | /api/hotels/featured | 인기 숙소 |
| GET | /api/hotels/regions | 지역 목록 |
| GET | /api/hotels/search | 숙소 검색 (`?lang=en` 번역 지원) |
| GET | /api/hotels/:id | 숙소 상세 |
| POST | /api/hotels | 숙소 등록 (호스트) |
| PUT | /api/hotels/:id | 숙소 수정 (호스트) |
| GET | /api/hotels/:id/rooms/:roomId | 객실 상세 |
| POST | /api/hotels/:id/rooms | 객실 등록 (호스트) |
| GET | /api/hotels/:id/rooms/:roomId/availability | 가용 여부 확인 |

### 예약
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | /api/bookings | 예약 생성 |
| GET | /api/bookings | 내 예약 목록 |
| GET | /api/bookings/host | 호스트 예약 목록 |
| GET | /api/bookings/:id | 예약 상세 |
| DELETE | /api/bookings/:id | 예약 취소 |

### 리뷰 / 위시리스트
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | /api/hotels/:id/reviews | 리뷰 목록 |
| POST | /api/reviews | 리뷰 작성 |
| DELETE | /api/reviews/:id | 리뷰 삭제 |
| POST | /api/wishlist/:hotelId | 위시리스트 토글 |
| GET | /api/wishlist | 위시리스트 조회 |

---

## 기술 스택

### 백엔드
- Node.js + TypeScript
- Express.js
- MySQL2 (로컬 MySQL / AWS RDS)
- AWS SDK v3 (DynamoDB, Translate)
- jsonwebtoken / aws-jwt-verify (로컬 JWT / Cognito)
- bcryptjs

### 프론트엔드
- Vanilla HTML5 / CSS3 / JavaScript (ES6+)
- Nginx (정적 서빙 + API 프록시)
- 모바일 반응형 디자인

### 인프라 (예정 — Terraform)
- **컴퓨팅**: EC2 (Frontend + Backend) + ELB + ASG + ECR/ECS
- **데이터**: RDS MySQL + DynamoDB
- **인증**: AWS Cognito
- **API**: API Gateway + WAF
- **AI**: Bedrock + Lex + Comprehend + Rekognition + Amazon Translate
- **배포**: CodePipeline + CodeBuild + CodeDeploy
- **보안**: IAM + CloudTrail + SSM Parameter Store
- **모니터링**: CloudWatch + Athena + EventBridge + SQS + SNS
- **글로벌**: CloudFront + Route 53 + Global Accelerator

---

## AWS 아키텍처

```
사용자
  │
  ├── Route 53 → CloudFront
  │                  │
  │             EC2 Frontend (Nginx)
  │
  └── API Gateway + WAF + Cognito
              │
          ELB (ALB)
              │
           ASG + EC2 Backend (Express.js)
              │
      ┌───────┼────────┐
      │       │        │
   RDS      DynamoDB   S3
  MySQL    (세션/캐시) (이미지)
              │
          Lambda (AI/비동기)
          ├── Amazon Translate
          ├── Bedrock
          ├── Comprehend
          └── Rekognition
```

---

## 환경변수

### 로컬 (`.env.local` — 커밋됨)

```env
APP_MODE=local
DB_HOST=mysql
JWT_SECRET=local-dev-secret-key-2024
DYNAMO_ENDPOINT=http://dynamodb-local:8000
```

### AWS (`.env.aws` — `.env.aws.example` 참고, 커밋 금지)

```env
APP_MODE=aws
DB_HOST=<rds-endpoint>.rds.amazonaws.com
COGNITO_USER_POOL_ID=ap-northeast-2_XXXXXXXXX
COGNITO_CLIENT_ID=<client-id>
DYNAMO_TABLE=TravelBookingCache
AWS_REGION=ap-northeast-2
```

---

## 트러블슈팅

```bash
# 컨테이너 상태 확인
docker compose -f docker-compose.local.yml ps

# 백엔드 로그
docker compose -f docker-compose.local.yml logs backend

# 전체 초기화 (볼륨 포함)
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up --build
```

포트 충돌 시 `docker-compose.local.yml`에서 포트 번호 변경 후 재실행하세요.

| 서비스 | 기본 포트 |
|--------|---------|
| Frontend (Nginx) | 80 |
| Backend (Express) | 3000 |
| MySQL | 3306 |
| DynamoDB Local | 8000 |
