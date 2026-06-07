# ── VPC Endpoint 보안 그룹 ────────────────────────────────────────────────────
resource "aws_security_group" "vpc_endpoints" {
  name        = "ThreeTier-VPCEndpoints-SG"
  description = "VPC Endpoints Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-VPCEndpoints-SG" }

  ingress {
    from_port   = 443
    to_port     = 443
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

# ── Gateway Endpoint (무료) ───────────────────────────────────────────────────
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [
    aws_route_table.private_backend.id,
    aws_route_table.private_db.id
  ]
  tags = { Name = "ThreeTier-S3-Endpoint" }
}

# ── Interface Endpoints ───────────────────────────────────────────────────────
locals {
  interface_endpoints = toset([
    "ecr.api",
    "ecr.dkr",
    "logs",
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager",
    "sqs",
    "guardduty-data"
  ])
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "ThreeTier-${each.key}-Endpoint" }
}
