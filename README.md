# AI 여행 예약 플랫폼 — Project TEAM AWS

야놀자 스타일의 여행 및 숙박 예약 플랫폼.  
**프론트엔드는 AWS Amplify**, **백엔드는 Docker(ECS) 또는 로컬 Docker**로 실행합니다.

---

## 아키텍처

```
프론트엔드  →  AWS Amplify (정적 호스팅)
백엔드      →  ECR + ECS (Fargate) 또는 로컬 Docker
DB          →  RDS MySQL + DynamoDB
인증        →  AWS Cognito
```

---

## Amplify 배포 (프론트엔드)

#### 1. Amplify 콘솔에서 GitHub 연결
```
AWS Amplify 콘솔 → 새 앱 → GitHub 저장소 연결
브랜치: main
```

#### 2. 환경변수 설정
```
Amplify 콘솔 → 앱 설정 → 환경변수
API_URL = https://<백엔드-도메인>   (ECS/EC2 백엔드 주소)
```

#### 3. 빌드 설정
루트의 `amplify.yml`이 자동으로 사용됩니다.  
빌드 시 `config.js`에 백엔드 URL이 자동 주입됩니다.

#### 4. 백엔드 CORS 설정
```env
# backend/.env.aws
CORS_ORIGIN=https://<amplify-app-id>.amplifyapp.com
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
docker compose -f docker-compose.local.yml up --build -d

# AWS 연동 모드 실행 (.env.aws 파일 먼저 작성)
cp backend/.env.aws.example backend/.env.aws
# .env.aws 에 RDS endpoint, Cognito ID 등 실제 값 입력
docker compose -f docker-compose.aws.yml up --build -d
```

---

## 테스트 계정

| 역할 | 이메일 | 비밀번호 |
|------|--------|---------|
| 관리자 | admin@travel.com | password123 |
| 호스트 | host@travel.com | password123 |
| 일반 | user@travel.com | password123 |

---

## AWS EC2 배포

### 방법 1 — EC2 1대에 docker-compose 그대로 실행 (가장 빠름)

#### 1. EC2 인스턴스 생성
- AMI: **Amazon Linux 2023** 또는 **Ubuntu 22.04**
- 인스턴스 타입: `t3.small` 이상 (t2.micro는 메모리 부족 가능)
- 보안 그룹 인바운드 규칙:

| 포트 | 프로토콜 | 소스 |
|------|---------|------|
| 22 | TCP | 내 IP |
| 80 | TCP | 0.0.0.0/0 |
| 3000 | TCP | 0.0.0.0/0 |

#### 2. EC2 접속 후 환경 세팅

```bash
# Amazon Linux 2023
sudo yum install -y docker git
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user

# Docker Compose 플러그인 설치
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
# Docker BuildX 업데이트
sudo curl -SL https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64 \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

# 재로그인 (docker 그룹 적용)
exit
```

```bash
# Ubuntu 22.04
sudo apt update && sudo apt install -y docker.io docker-compose-plugin git
sudo systemctl start docker
sudo usermod -aG docker ubuntu
exit   # 재로그인
```

#### 3. 배포 및 실행

```bash
# 메모리 부족 상황을 대비한 스왑 파일 추가
sudo dd if=/dev/zero of=/swapfile bs=128M count=16
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile swap swap defaults 0 0' | sudo tee -a /etc/fstab

# 프로젝트 복제(다운로드)
git clone https://github.com/yubin05/Project_TEAM_AWS.git
cd Project_TEAM_AWS

# 백엔드 빌드 및 실행
docker compose -f docker-compose.local.yml up --build -d
docker compose -f docker-compose.local.yml exec backend npm run seed
```

#### 4. 로그 디렉토리 생성 (CloudWatch Agent 연동 시)

```bash
sudo mkdir -p /var/log/app
sudo chown ec2-user:ec2-user /var/log/app
```

> 앱 실행 시 `LOG_DIR=/var/log/app`이 자동으로 적용되어 `/var/log/app/app.log`, `/var/log/app/error.log`에 로그가 쌓입니다.

#### 5. 프론트엔드 실행 (http-server) - Amplify 미적용 시

```bash
# Node.js 설치 (없는 경우)
sudo yum install -y nodejs   # Amazon Linux
# sudo apt install -y nodejs  # Ubuntu

# http-server 설치 및 실행
sudo npm install -g http-server
http-server ~/Project_TEAM_AWS/frontend/public -p 8080 -c-1
```

백그라운드 실행:
```bash
nohup http-server ~/Project_TEAM_AWS/frontend/public -p 8080 -c-1 &
```

#### 6. 접속 확인

```
프론트엔드:  http://<EC2 퍼블릭 IP>:8080
API:         http://<EC2 퍼블릭 IP>:3000/api
```

> 보안 그룹 인바운드에 **8080 포트** 추가 필요

---

### 방법 2 — EC2 2대 + RDS MySQL

프론트엔드 EC2 / 백엔드 EC2 분리, DB는 RDS로 교체합니다.

#### 1. RDS 생성
- 엔진: MySQL 8.0
- 인스턴스: `db.t3.micro`
- DB명: `travel_booking`
- 퍼블릭 액세스: **비활성화**
- 보안 그룹: 백엔드 EC2 SG에서 포트 3306 허용

#### 2. 백엔드 EC2 환경변수 설정

```bash
# .env.local 기반으로 DB_HOST만 RDS 엔드포인트로 변경
cat > backend/.env.local << 'EOF'
APP_MODE=local
DB_HOST=<rds-endpoint>.rds.amazonaws.com
JWT_SECRET=local-dev-secret-key-2024
DYNAMO_ENDPOINT=http://dynamodb-local:8000
EOF
```

#### 3. docker-compose에서 mysql 서비스 제거

`docker-compose.local.yml`의 `mysql` 서비스와 백엔드 `depends_on.mysql` 항목을 제거하고 실행:

```bash
docker compose -f docker-compose.local.yml up --build -d
docker compose -f docker-compose.local.yml exec backend npm run seed
```

---

### 방법 3 — 풀 AWS 모드 (Cognito + RDS + DynamoDB + Translate)

#### 1. 필요한 AWS 리소스 준비
- **Cognito**: User Pool 생성, `custom:role` 속성 추가
- **RDS**: MySQL 8.0, DB명 `travel_booking`
- **DynamoDB**: 테이블 `TravelBookingCache` 생성 (파티션 키: `pk`)
- **IAM Role**: EC2에 DynamoDB + Translate 권한 부여

#### 2. 환경변수 작성

```bash
cp backend/.env.aws.example backend/.env.aws
```

```env
APP_MODE=aws
DB_HOST=<rds-endpoint>.rds.amazonaws.com
DB_USER=admin
DB_PASSWORD=<password>
DB_NAME=travel_booking
COGNITO_USER_POOL_ID=ap-northeast-2_XXXXXXXXX
COGNITO_CLIENT_ID=<client-id>
DYNAMO_TABLE=TravelBookingCache
AWS_REGION=ap-northeast-2
CORS_ORIGIN=http://<frontend-ec2-ip>
```

#### 3. 실행

```bash
docker compose -f docker-compose.aws.yml up --build -d
```

> **IAM Role 권한 정책 예시**
> ```json
> {
>   "Effect": "Allow",
>   "Action": [
>     "dynamodb:GetItem", "dynamodb:PutItem",
>     "translate:TranslateText"
>   ],
>   "Resource": "*"
> }
> ```

---

## 프로젝트 구조

```
Project_TEAM_AWS/
├── amplify.yml                     Amplify 빌드 스펙
├── docker-compose.local.yml        로컬 테스트 (백엔드만)
├── docker-compose.aws.yml          AWS 연동 버전
│
├── frontend/                       → AWS Amplify로 배포
│   └── public/
│       ├── index.html
│       ├── css/style.css
│       └── js/
│           ├── config.js           API URL 설정 (환경별 자동 교체)
│           └── app.js
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

### 공통

```bash
# 컨테이너 상태 확인
docker compose -f docker-compose.local.yml ps

# 백엔드 로그
docker compose -f docker-compose.local.yml logs backend

# MySQL 로그
docker compose -f docker-compose.local.yml logs mysql

# 전체 초기화 (볼륨 포함)
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up --build -d
```

포트 충돌 시 `docker-compose.local.yml`에서 포트 번호 변경 후 재실행하세요.

| 서비스 | 기본 포트 |
|--------|---------|
| Frontend (Nginx) | 80 |
| Backend (Express) | 3000 |
| MySQL | 3306 |
| DynamoDB Local | 8000 |
