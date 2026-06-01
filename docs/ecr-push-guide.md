# ECR 이미지 수동 Push 가이드

## 사전 준비

Docker Desktop 설치 (미설치 시):
```cmd
winget install Docker.DockerDesktop
```
설치 후 PC 재시작 → Docker Desktop 실행 확인 후 진행.

```cmd
set AWS_PROFILE=<Your Profile>
set ACCOUNT_ID=<Your Account ID>
set REGION=ap-northeast-2
```

## 1. ECR 로그인

```cmd
aws ecr get-login-password --region %REGION% | docker login --username AWS --password-stdin %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com
```

## 2. 이미지 빌드 + 태그 + Push (4개 서비스)

프로젝트 루트에서 실행:

```cmd
docker build -t auth-service ./backend/auth-service
docker tag auth-service:latest %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/auth-service:latest
docker push %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/auth-service:latest

docker build -t hotel-service ./backend/hotel-service
docker tag hotel-service:latest %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/hotel-service:latest
docker push %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/hotel-service:latest

docker build -t booking-service ./backend/booking-service
docker tag booking-service:latest %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/booking-service:latest
docker push %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/booking-service:latest

docker build -t review-service ./backend/review-service
docker tag review-service:latest %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/review-service:latest
docker push %ACCOUNT_ID%.dkr.ecr.%REGION%.amazonaws.com/review-service:latest
```

## 3. ECS 강제 재배포

이미지 push 후 ECS 서비스 재시작:

```cmd
aws ecs update-service --cluster ThreeTier-Cluster --service auth-service --force-new-deployment --region %REGION% --profile %AWS_PROFILE%
aws ecs update-service --cluster ThreeTier-Cluster --service hotel-service --force-new-deployment --region %REGION% --profile %AWS_PROFILE%
aws ecs update-service --cluster ThreeTier-Cluster --service booking-service --force-new-deployment --region %REGION% --profile %AWS_PROFILE%
aws ecs update-service --cluster ThreeTier-Cluster --service review-service --force-new-deployment --region %REGION% --profile %AWS_PROFILE%
```
