# 인프라 파트 발표 시나리오

---

## 1. 프로젝트 시나리오

Sponge Trip은 한국 내 여행 및 숙박 예약 서비스로 시작했으나, 바이럴 이후 일본·동남아시아 등 해외 사용자 유입이 급증하며 Sponge Company는 글로벌 서비스 확장을 검토 중이다.

현재 고객사는 온프레미스 데이터 센터에 아래와 같이 서버를 운영 중이다.

| 서버 | 사양 | 역할 |
|------|------|------|
| 웹 서버 1대 | Nginx | 프론트엔드 정적 파일 서빙 |
| 백엔드 API 서버 4대 | Docker 컨테이너 | 숙소 검색·예약·리뷰·인증 API |
| DB 서버 1대 | MySQL | 예약·사용자·숙소 데이터 저장 |

### 인기 폭발 배경

2026년 초, 구독자 150만 명의 국내 유명 여행 유튜버 채널에서 Sponge Trip을 소개하는 영상이 업로드되었다. 해당 영상은 24시간 만에 조회수 800만을 돌파하며 SNS 전방위로 바이럴됐고, 신규 가입자와 예약 요청이 폭발적으로 증가했다.

| 지표 | 바이럴 이전 | 바이럴 직후 |
|------|------------|------------|
| 일 활성 사용자(DAU) | 약 5,000명 | 약 200,000명 (40배 ↑) |
| 동시 접속자 | 약 500명 | 약 20,000명 |
| 초당 예약 요청 | 약 10건 | 약 300건 |

기존 온프레미스 서버는 급증한 트래픽을 감당하지 못해 **서비스 전체가 약 4시간 다운**되었고, 이로 인해 예약 기회 손실 및 브랜드 신뢰도 타격이 발생했다.

이에 Sponge Company는 **클라우드 기반의 고가용성 인프라** 구축을 결정했다.

---

## 2. 가상 고객 요구사항

### 고가용성 및 완전관리형 전환

고객사는 성수기나 이벤트 기간 트래픽 급증 시 프론트엔드·백엔드·데이터베이스 전 레이어가 다운 없이 자동 대응되기를 원한다.
또한 서버 패치, 스케일링, 장애 복구 등을 직접 관리하는 오버헤드 없이 **완전관리형(Fully Managed)** 서비스로 운영되기를 요구한다.

| 레이어 | 기존 (온프레미스) | 전환 후 (AWS) | 이점 |
|--------|-----------------|--------------|------|
| 프론트엔드 | Nginx (수동 관리) | **Amplify** | GitHub 연동 자동 배포, 내장 CDN, 서버 관리 불필요 |
| 백엔드 | Docker (수동 운영) | **ECS Fargate** | 컨테이너 오케스트레이션 자동화, 트래픽에 따른 Auto Scaling |
| 데이터베이스 | MySQL (단일 서버) | **Aurora Serverless v2** | 트래픽 급증 시 자동 확장, 자동 Failover (30초 이내) |

- 프론트엔드: Amplify CDN이 전 세계 엣지에서 정적 파일 서빙 → 서버 부하 없이 대용량 트래픽 처리
- 백엔드: ECS Fargate Auto Scaling으로 트래픽 증가 시 컨테이너 자동 증설, 감소 시 자동 축소
- 데이터베이스: Aurora Serverless v2 — 0.5 ACU ~ 4 ACU 자동 조절, Writer 장애 시 Reader → Writer 자동 승격 (30초 이내)

### 글로벌 서비스 확장

국내 바이럴 이후 일본·동남아시아 사용자 유입이 늘어나며 고객사는 해외 시장 진출을 원한다.

- 일본·동남아 등 해외 사용자에게도 국내와 동일한 응답 속도를 제공해야 한다.
- 특정 국가의 클라우드 장애 시에도 다른 리전에서 서비스가 유지되어야 한다.
- 글로벌 사용자를 고려해 정적 파일은 CDN 엣지에서 빠르게 서빙되어야 한다.

> **현재 구현 범위**: 서울 리전(ap-northeast-2) 단일 구성으로 초안 제출
> **추후 확장 계획** *(일정 여유 시 반영)*: AWS Global Accelerator + 도쿄 리전(ap-northeast-1) 멀티 리전 배포 → 일본·동남아 사용자에게 가장 가까운 리전으로 자동 라우팅
> 비용 절감을 우선으로, 고가용성 없이 도쿄 리전(ap-northeast-1)에 **최소 구성**으로 확장
> - 단일 서브넷, 단일 RDS 인스턴스 (Multi-AZ 미적용)
> - 시장 반응 확인 후 트래픽이 충분히 증가하면 HA 구성으로 업그레이드
> - Route 53 지연 기반 라우팅으로 일본·동남아 사용자는 도쿄 리전으로 자동 연결

### 재해복구 (AWS 장애 대비 멀티클라우드)

고객사는 특정 클라우드 리전 장애 시에도 서비스가 중단되지 않기를 원한다.

- 단일 클라우드 의존을 탈피하여 AWS 장애 시 Azure로 자동 전환되어야 한다.
- 정상 시에도 AWS와 Azure가 동시에 트래픽을 처리하는 Active-Active 구성이어야 한다.
- AWS 장애 발생 시 60초 이내 자동 전환(RTO), 데이터 손실은 5분 이내(RPO)로 최소화해야 한다.
- 이미지·정적 파일은 S3와 Azure Blob Storage 간 양방향 동기화로 어느 쪽에서든 제공되어야 한다.

```
글로벌 사용자
      │
      ▼
Route 53 (AWS) ──────── Azure Traffic Manager
      │                        │
      ├── Amplify (CDN)        ├── Azure Static Web Apps (CDN)
      │   프론트엔드           │   프론트엔드 이중화
      │                        │
      ▼                        ▼
API Gateway (AWS)     Azure API Management
  ↓ VPC Link              ↓
ALB → ECS (AWS)       Azure Container Apps
  ↓                        ↓
Aurora MySQL (AWS)  ←──→  Azure Database for MySQL
                    양방향 동기화
S3 (AWS)            ←──→  Azure Blob Storage
                    Storage Replication
```

| 구분 | 내용 |
|------|------|
| 정상 시 | Route 53이 AWS(70%) + Azure(30%) 가중치 라우팅 |
| 장애 시 | Route 53 헬스체크 실패 → Azure 100% 자동 전환 |
| RTO | 60초 이내 (DNS TTL 기반) |
| RPO | 5분 이내 (DB 동기화 주기) |

---

## 3. 본인이 사용할 리소스

### 핵심 인프라 (AWS)

| 서비스 | 용도 |
|--------|------|
| VPC | 네트워크 격리 및 보안 경계 구성 |
| ECS | 4개 마이크로서비스 컨테이너 실행 (Fargate, Auto Scaling) |
| ECR | 서비스별 Docker 이미지 저장소 (IMMUTABLE 태그) |
| ALB | 서비스별 전용 리스너(3001~3004), Blue/Green 배포 지원 |
| API Gateway | 외부 진입점, HTTPS, 서비스별 라우팅, Cognito JWT 인증 |
| Aurora | Serverless v2 자동 스케일링, Reader Auto Scaling, 자동 Failover |
| Amplify | 프론트엔드 CDN 자동 배포 (경로 필터로 불필요한 빌드 방지) |
| Route 53 | 가중치 기반 라우팅 (AWS 70% / Azure 30%), 헬스체크 장애 전환 |
| S3 | 정적 파일·이미지 원본 저장, Azure Blob Storage 양방향 동기화 |

### 멀티클라우드 재해복구용 인프라 (Azure)

| 서비스 | 역할 |
|--------|------|
| Azure Static Web Apps | Amplify와 프론트엔드 이중화 (자동 빌드/배포, 내장 CDN) |
| Azure Traffic Manager | Azure 측 트래픽 분산 및 헬스체크 |
| Azure Blob Storage | S3와 이미지·정적 파일 양방향 동기화 |
| Azure API Management | AWS API Gateway와 양방향 API 게이트웨이 구성 |

---

## 4. 본인이 원하는 세부적인 IAM 역할

### VPC / Networking
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:CreateVpc", "ec2:DeleteVpc",
      "ec2:CreateSubnet", "ec2:DeleteSubnet",
      "ec2:CreateInternetGateway", "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway", "ec2:DeleteInternetGateway",
      "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
      "ec2:CreateRoute", "ec2:DeleteRoute",
      "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
      "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress", "ec2:RevokeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress", "ec2:RevokeSecurityGroupEgress",
      "ec2:AllocateAddress", "ec2:ReleaseAddress",
      "ec2:AssociateAddress", "ec2:DisassociateAddress",
      "ec2:CreateNetworkInterface", "ec2:DeleteNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:CreateTags", "ec2:DeleteTags",
      "ec2:Describe*"
    ],
    "Resource": "*"
  }]
}
```

### EC2 (NAT Instance, MySQL EC2)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:RunInstances", "ec2:TerminateInstances",
      "ec2:StartInstances", "ec2:StopInstances",
      "ec2:ModifyInstanceAttribute"
    ],
    "Resource": "*"
  }]
}
```

### ECR
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ecr:CreateRepository", "ecr:DeleteRepository",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload",
      "ecr:PutImage", "ecr:UploadLayerPart",
      "ecr:BatchDeleteImage",
      "ecr:PutImageTagMutability", "ecr:PutImageScanningConfiguration",
      "ecr:Describe*", "ecr:List*"
    ],
    "Resource": "*"
  }]
}
```

### ECS Fargate
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ecs:CreateCluster", "ecs:DeleteCluster",
      "ecs:RegisterTaskDefinition", "ecs:DeregisterTaskDefinition",
      "ecs:CreateService", "ecs:UpdateService", "ecs:DeleteService",
      "ecs:RunTask", "ecs:StopTask",
      "ecs:PutClusterCapacityProviders",
      "ecs:TagResource",
      "ecs:Describe*", "ecs:List*"
    ],
    "Resource": "*"
  }]
}
```

### ALB
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "elasticloadbalancing:CreateLoadBalancer", "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup", "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:CreateListener", "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:CreateRule", "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:ModifyListener", "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:RegisterTargets", "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:Describe*"
    ],
    "Resource": "*"
  }]
}
```

### API Gateway
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "apigateway:GET", "apigateway:POST",
      "apigateway:PUT", "apigateway:DELETE", "apigateway:PATCH"
    ],
    "Resource": "*"
  }]
}
```

### Aurora (RDS + Auto Scaling)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AuroraCluster",
      "Effect": "Allow",
      "Action": [
        "rds:CreateDBCluster", "rds:DeleteDBCluster",
        "rds:CreateDBInstance", "rds:DeleteDBInstance",
        "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup",
        "rds:CreateDBClusterSnapshot", "rds:DeleteDBClusterSnapshot",
        "rds:ModifyDBCluster", "rds:ModifyDBInstance",
        "rds:RestoreDBClusterFromSnapshot",
        "rds:AddTagsToResource",
        "rds:Describe*", "rds:List*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ReaderAutoScaling",
      "Effect": "Allow",
      "Action": [
        "application-autoscaling:RegisterScalableTarget",
        "application-autoscaling:DeregisterScalableTarget",
        "application-autoscaling:PutScalingPolicy",
        "application-autoscaling:DeleteScalingPolicy",
        "application-autoscaling:Describe*"
      ],
      "Resource": "*"
    }
  ]
}
```

### Amplify
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "amplify:CreateApp", "amplify:DeleteApp", "amplify:UpdateApp",
      "amplify:CreateBranch", "amplify:DeleteBranch",
      "amplify:StartJob", "amplify:StopJob",
      "amplify:Get*", "amplify:List*"
    ],
    "Resource": "*"
  }]
}
```

### Route 53
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "route53:CreateHostedZone", "route53:DeleteHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:CreateHealthCheck", "route53:DeleteHealthCheck",
      "route53:UpdateHealthCheck",
      "route53:Get*", "route53:List*"
    ],
    "Resource": "*"
  }]
}
```

### S3
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:CreateBucket", "s3:DeleteBucket",
      "s3:PutObject", "s3:GetObject", "s3:DeleteObject",
      "s3:ListBucket",
      "s3:PutBucketVersioning", "s3:PutBucketPolicy",
      "s3:PutBucketReplication",
      "s3:GetBucketLocation"
    ],
    "Resource": "*"
  }]
}
```

### IAM (PassRole — ECS Task Role, EC2 Instance Profile 연결 필요)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "iam:CreateRole", "iam:DeleteRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:PassRole",
      "iam:GetRole", "iam:List*"
    ],
    "Resource": "*"
  }]
}
```

### SSM Session Manager
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ssm:StartSession", "ssm:TerminateSession",
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus"
    ],
    "Resource": "*"
  }]
}
```

### Terraform State (S3 — Terraform v1.10+ use_lockfile=true)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject", "s3:PutObject",
      "s3:ListBucket", "s3:DeleteObject",
      "s3:GetBucketVersioning", "s3:PutBucketVersioning"
    ],
    "Resource": "*"
  }]
}
```

---

## 5. 본인 파트에 필요한 실제 사례

### 보안 사고 사례 — 왜 클라우드 보안이 필요한가

#### 야놀자 개인정보 유출 (2019, 2021)
- 2019년: 야놀자펜션앱 DB 해킹으로 고객 개인정보 **약 7만 건** 유출 (이메일, 전화번호)
- 2021년: 클라우드 관리 소홀(접근 권한 미설정)로 **5만 2천 건** 추가 유출
- 참고: [전자신문](https://www.etnews.com/20190328000230) / [보안뉴스](http://www.boannews.com/media/view.asp?idx=78254)

#### Booking.com 피싱 공격 (2023~2024)
- 2023년부터 호텔 파트너를 대상으로 한 악성코드 공격 → 고객 예약 정보 탈취 후 피싱 메시지 발송
- 2024년: Booking.com 발표 — 피싱 공격 **900% 증가** (AI 도구 활용)
- 피해: 영국에서만 피해액 **£370,000(약 6억 원)**
- 참고: [Krebs on Security](https://krebsonsecurity.com/2024/11/booking-com-phishers-may-leave-you-with-reservations/) / [Malwarebytes](https://www.malwarebytes.com/blog/data-breaches/2026/04/booking-com-breach-gives-scammers-what-they-need-to-target-guests)

#### Agoda 8,200만 건 유출 의혹 (2025)
- 해커 포럼에 고객 정보 **8,200만 건** 판매 게시 (이름, 이메일, 전화번호, 신분증 번호)
- Agoda 측은 부인했으나 샘플 데이터의 실존 여부 논란 지속
- 참고: [Cybernews](https://cybernews.com/security/agoda-data-breach-82m-hacker-forum/)

---

### AWS 장애 사례 — 왜 멀티클라우드가 필요한가

#### AWS 서울 리전 장애
- AWS 서울 리전(ap-northeast-2) 장애로 국내 주요 서비스 접속 오류 발생
- 참고: [Korea Herald](https://www.koreaherald.com/article/1844752)

#### AWS 글로벌 대규모 장애 (2025년 10월)
- 2025년 10월 US-EAST-1 광범위 장애 → 멀티 리전 구성 없는 기업들 대규모 서비스 중단
- 단일 클라우드 의존의 위험성 입증
- 참고: [INE Blog](https://ine.com/blog/aws-october-2025-outage-multi-region-and-cloud-lessons-learned)
