# NAT Instance SG: VPC 내부 트래픽 포워딩 허용 (SSH 외부 오픈 없음 — SSM으로 접속)
resource "aws_security_group" "nat_instance" {
  name        = "ThreeTier-NATInstance-SG"
  description = "NAT Instance Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-NATInstance-SG" }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "VPC internal to internet NAT forwarding"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
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

# MySQL SG: 백엔드 서브넷(10.1.2.0/24)에서만 3306 허용
resource "aws_security_group" "mysql" {
  name        = "ThreeTier-MySQL-SG"
  description = "MySQL EC2 Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-MySQL-SG" }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "Backend services to MySQL port 3306"
    from_port   = 3306
    to_port     = 3306
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

  lifecycle {
    ignore_changes = [ingress]
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
    description = "MySQL from backend and on-premises DB subnet"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = concat(["10.1.2.0/24", "10.1.5.0/24"], var.enable_migration ? ["10.1.3.0/24"] : [])
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
