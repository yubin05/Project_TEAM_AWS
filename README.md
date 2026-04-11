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
docker compose -f docker-compose.local.yml up --build -d

# 3. 시드 데이터 입력 (최초 1회)
docker compose -f docker-compose.local.yml exec backend npm run seed

# 4. 접속
# 프론트엔드:  http://localhost
# API:         http://localhost:3000/api
# 헬스체크:    http://localhost:3000/health
```

### 데이터 초기화
```bash
# 볼륨 포함 전체 초기화
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up --build -d
docker compose -f docker-compose.local.yml exec backend npm run seed
```

### 로컬 환경 전제 조건

**Ubuntu**

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo systemctl start docker
sudo usermod -aG docker $USER   # 재로그인 후 sudo 없이 사용 가능
```

**CentOS 7 (VMware Pro Station)**

```bash
# 1. 기존 Docker 제거
sudo yum remove -y docker docker-common docker-selinux docker-engine

# 2. 필수 패키지 설치
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# 3. Docker 공식 저장소 추가
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 4. Docker CE + Compose 플러그인 설치
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 5. Docker 시작 및 부팅 자동 실행 등록
sudo systemctl start docker
sudo systemctl enable docker

# 6. 현재 사용자를 docker 그룹에 추가 (재로그인 필요)
sudo usermod -aG docker $USER

# 7. SELinux 설정 (컨테이너 볼륨 마운트 오류 방지)
# 방법 A — Permissive 모드로 전환 (간단, 재부팅 후에도 유지)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# 방법 B — Enforcing 유지 시 볼륨에 레이블 부여 (보안 유지)
# docker-compose.local.yml 볼륨에 :z 옵션 추가 필요
# 예) - mysql_data:/var/lib/mysql:z

# 8. 방화벽 포트 개방
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --reload

# 9. git 설치 (없는 경우)
sudo yum install -y git

# 10. 재로그인 후 docker 그룹 적용 확인
newgrp docker
docker --version
docker compose version
```

> **CentOS 7 주의사항**
> - `docker-compose` (V1, 하이픈) 대신 `docker compose` (V2, 공백) 사용
> - SELinux Enforcing 상태에서 MySQL 볼륨 마운트 실패 시 방법 A 또는 B 적용
> - VMware 네트워크 어댑터를 **NAT** 또는 **브리지**로 설정해야 외부 이미지 pull 가능

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
git clone https://github.com/yubin05/Project_TEAM_AWS.git
cd Project_TEAM_AWS

docker compose -f docker-compose.local.yml up --build -d
docker compose -f docker-compose.local.yml exec backend npm run seed
```

#### 4. 접속 확인

```
http://<EC2 퍼블릭 IP>
```

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

---

### CentOS 7 환경별 오류

**`docker compose` 명령어를 찾을 수 없음**
```bash
sudo yum install -y docker-compose-plugin
docker compose version
```

**MySQL 컨테이너 볼륨 마운트 실패 (SELinux)**
```bash
getenforce   # Enforcing 이면 문제 발생 가능
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

**포트 80 접속 불가 (방화벽)**
```bash
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
```

**`permission denied` — docker 명령 실행 불가**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

**이미지 pull 실패 (VMware 네트워크)**
```bash
cat /etc/resolv.conf
sudo systemctl restart NetworkManager
ping google.com
```

**`/usr/sbin/mysqld: Can't create/write to file` (tmpdir 권한)**
```bash
docker compose -f docker-compose.local.yml down -v
docker compose -f docker-compose.local.yml up --build -d
```
