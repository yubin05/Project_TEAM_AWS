
# Frontend SG: 외부 HTTP 80만 허용 (SSH 외부 오픈 없음 — SSM으로 접속)
resource "aws_security_group" "frontend" {
  name        = "ThreeTier-Frontend-SG"
  description = "Frontend EC2 (nginx) Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-Frontend-SG" }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Backend SG: Frontend(10.1.1.0/24) 및 서비스 간 통신(10.1.2.0/24) 허용
resource "aws_security_group" "backend" {
  name        = "ThreeTier-Backend-SG"
  description = "Backend Services Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-Backend-SG" }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "Frontend to backend service ports 3001-3005"
    from_port   = 3001
    to_port     = 3005
    protocol    = "tcp"
    cidr_blocks = ["10.1.1.0/24"]
  }

  ingress {
    description = "Inter-service communication"
    from_port   = 3001
    to_port     = 3005
    protocol    = "tcp"
    cidr_blocks = ["10.1.2.0/24"]
  }

  ingress {
    description = "ElasticMQ on hotel EC2 port 9324 for booking and review"
    from_port   = 9324
    to_port     = 9324
    protocol    = "tcp"
    cidr_blocks = ["10.1.2.0/24"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CGW SG: StrongSwan EC2 — VPN 터널 수립 및 트래픽 포워딩
resource "aws_security_group" "cgw" {
  count       = var.enable_migration ? 1 : 0
  name        = "ThreeTier-CGW-SG"
  description = "StrongSwan CGW EC2 Security Group (IDC VPC)"
  vpc_id      = aws_vpc.idc[0].id
  tags        = { Name = "ThreeTier-CGW-SG" }

  ingress {
    description = "IKE - IPSec tunnel negotiation"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IKE NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ESP - IPSec encrypted packets"
    from_port   = -1
    to_port     = -1
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IDC VPC internal forwarding traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# MySQL SG: IDC VPC에 위치 (온프레미스 시뮬레이션)
# DMS(Main VPC 10.1.2.x/10.1.5.x)에서 VPN 경유로 3306 접근
resource "aws_security_group" "mysql" {
  count       = var.enable_migration ? 1 : 0
  name        = "ThreeTier-MySQL-SG"
  description = "MySQL EC2 Security Group (IDC VPC)"
  vpc_id      = aws_vpc.idc[0].id
  tags        = { Name = "ThreeTier-MySQL-SG" }

  ingress {
    description = "DMS replication instance via Site-to-Site VPN"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.2.0/24", "10.1.5.0/24"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB SG: VPC 내부(API Gateway VPC Link)에서 서비스 포트 허용
resource "aws_security_group" "alb" {
  name        = "ThreeTier-ALB-SG"
  description = "Internal ALB Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-ALB-SG" }

  ingress {
    description = "HTTP from VPC (API Gateway VPC Link)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "auth-service"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "hotel-service"
    from_port   = 3002
    to_port     = 3002
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "booking-service"
    from_port   = 3003
    to_port     = 3003
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "review-service"
    from_port   = 3004
    to_port     = 3004
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "support-service"
    from_port   = 3005
    to_port     = 3005
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Tasks SG: ALB에서 서비스 포트(3001-3005) 허용
resource "aws_security_group" "ecs_tasks" {
  name        = "ThreeTier-ECS-Tasks-SG"
  description = "ECS Fargate Tasks Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-ECS-Tasks-SG" }

  ingress {
    description     = "From ALB to service ports"
    from_port       = 3001
    to_port         = 3005
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS SG: 백엔드 및 온프레미스 DB 서브넷에서 3306 허용
resource "aws_security_group" "rds" {
  name        = "ThreeTier-RDS-SG"
  description = "Aurora MySQL Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-RDS-SG" }

  ingress {
    description = "MySQL from backend subnets and DMS"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.1.2.0/24", "10.1.5.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [ingress]
  }
}
