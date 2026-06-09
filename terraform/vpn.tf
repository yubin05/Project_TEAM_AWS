# ──────────────────────────────────────────────────────────────────────────────
# Site-to-Site VPN — IDC VPC(온프레미스) ↔ Main VPC(AWS)
#
# 구성 순서 (의존성):
#   EIP 생성 → Customer Gateway 등록 → VPN Connection 생성
#   → CGW EC2 user_data에 터널 파라미터 주입 → EIP를 CGW EC2에 연결
# ──────────────────────────────────────────────────────────────────────────────

# CGW EC2에 붙일 EIP (customer_gateway 등록 시 IP가 먼저 필요)
resource "aws_eip" "cgw" {
  count  = var.enable_migration ? 1 : 0
  domain = "vpc"
  tags   = { Name = "ThreeTier-CGW-EIP" }
}

# VPN Gateway — Main VPC 측 AWS 엔드포인트
# count 없음: IDC Full Load 완료 후에도 Azure CDC VPN에 계속 필요
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "ThreeTier-VGW" }
}

# VPN 라우트 자동 전파 — IDC(10.0.0.0/16) + Azure(10.2.0.0/16) 경로가 Main VPC RT에 자동 추가됨
resource "aws_vpn_gateway_route_propagation" "private_backend" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private_backend.id
  depends_on     = [aws_vpn_gateway.main]
}

resource "aws_vpn_gateway_route_propagation" "private_db" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.private_db.id
  depends_on     = [aws_vpn_gateway.main]
}

# Customer Gateway — IDC 측 VPN 엔드포인트 (CGW EC2 EIP로 등록)
resource "aws_customer_gateway" "idc" {
  count      = var.enable_migration ? 1 : 0
  bgp_asn    = 65000
  ip_address = aws_eip.cgw[0].public_ip
  type       = "ipsec.1"
  tags       = { Name = "ThreeTier-CGW" }
  depends_on = [aws_eip.cgw]
}

# VPN Connection (Static Routes Only — BGP 없이 정적 경로 사용)
resource "aws_vpn_connection" "main" {
  count               = var.enable_migration ? 1 : 0
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.idc[0].id
  type                = "ipsec.1"
  static_routes_only  = true
  tags                = { Name = "ThreeTier-VPN-Connection" }
}

# Static Route: IDC VPC CIDR → Main VPC via VPN
resource "aws_vpn_connection_route" "idc" {
  count                  = var.enable_migration ? 1 : 0
  vpn_connection_id      = aws_vpn_connection.main[0].id
  destination_cidr_block = "10.0.0.0/16"
}

# EIP → CGW EC2 연결 (EC2 생성 후 마지막에 연결)
resource "aws_eip_association" "cgw" {
  count         = var.enable_migration ? 1 : 0
  instance_id   = aws_instance.cgw[0].id
  allocation_id = aws_eip.cgw[0].id
  depends_on    = [aws_instance.cgw, aws_eip.cgw]
}
