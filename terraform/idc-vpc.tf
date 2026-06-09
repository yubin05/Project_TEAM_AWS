# ──────────────────────────────────────────────────────────────────────────────
# IDC VPC — 온프레미스 데이터센터 시뮬레이션 (Site-to-Site VPN으로 Main VPC 연결)
#
# enable_migration = true  → IDC VPC + VPN + MySQL EC2 + CGW EC2 전체 생성
# enable_migration = false → terraform apply 시 전체 자동 삭제
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "idc" {
  count                = var.enable_migration ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ThreeTier-IDC-VPC" }
}

resource "aws_internet_gateway" "idc" {
  count  = var.enable_migration ? 1 : 0
  vpc_id = aws_vpc.idc[0].id
  tags   = { Name = "ThreeTier-IDC-IGW" }
}

# Public Subnet — StrongSwan CGW EC2 (VPN 터미네이션, EIP 필요)
resource "aws_subnet" "idc_public" {
  count             = var.enable_migration ? 1 : 0
  vpc_id            = aws_vpc.idc[0].id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "ThreeTier-IDC-PublicSN" }
}

# Private Subnet — MySQL EC2 (온프레미스 DB 시뮬레이션)
resource "aws_subnet" "idc_private" {
  count             = var.enable_migration ? 1 : 0
  vpc_id            = aws_vpc.idc[0].id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "ThreeTier-IDC-PrivateSN" }
}

# ── Public Route Table (CGW EC2 → Internet for VPN) ────────────────────────
resource "aws_route_table" "idc_public" {
  count  = var.enable_migration ? 1 : 0
  vpc_id = aws_vpc.idc[0].id
  tags   = { Name = "ThreeTier-IDC-PublicRT" }
}

resource "aws_route" "idc_public_default" {
  count                  = var.enable_migration ? 1 : 0
  route_table_id         = aws_route_table.idc_public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.idc[0].id
}

resource "aws_route_table_association" "idc_public" {
  count          = var.enable_migration ? 1 : 0
  subnet_id      = aws_subnet.idc_public[0].id
  route_table_id = aws_route_table.idc_public[0].id
}

# ── Private Route Table (MySQL EC2 트래픽 → CGW EC2 경유) ───────────────────
resource "aws_route_table" "idc_private" {
  count  = var.enable_migration ? 1 : 0
  vpc_id = aws_vpc.idc[0].id
  tags   = { Name = "ThreeTier-IDC-PrivateRT" }
}

# Main VPC 대역 → CGW EC2 (VPN 통해 라우팅)
resource "aws_route" "idc_private_to_main_vpc" {
  count                  = var.enable_migration ? 1 : 0
  route_table_id         = aws_route_table.idc_private[0].id
  destination_cidr_block = "10.1.0.0/16"
  network_interface_id   = aws_instance.cgw[0].primary_network_interface_id
  depends_on             = [aws_instance.cgw]
}

# 인터넷 트래픽도 CGW EC2 경유 (SSM Agent 등 아웃바운드 필요)
resource "aws_route" "idc_private_default" {
  count                  = var.enable_migration ? 1 : 0
  route_table_id         = aws_route_table.idc_private[0].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.cgw[0].primary_network_interface_id
  depends_on             = [aws_instance.cgw]
}

resource "aws_route_table_association" "idc_private" {
  count          = var.enable_migration ? 1 : 0
  subnet_id      = aws_subnet.idc_private[0].id
  route_table_id = aws_route_table.idc_private[0].id
}
