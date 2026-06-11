# ──────────────────────────────────────────────────────────────────────────────
# Site-to-Site VPN — Main VPC(AWS) ↔ Azure VNet(DR)
#
# 전제: 팀원(김유빈) vpn.tf의 aws_vpn_gateway.main 공유 사용 (VPC당 VGW 1개 제한)
# 순서: 1) terraform-azure/ apply → Azure VPN Gateway 퍼블릭 IP 취득
#        2) azure_vpn_gateway_ip + vpn_shared_key를 terraform.tfvars에 입력
#        3) 이 파일 terraform apply → vpn_azure_tunnel1_address 출력
#        4) 출력된 터널 IP → terraform-azure/terraform.tfvars aws_vpn_tunnel_ip 입력
#        5) Azure Connection apply → 양방향 터널 UP
# ──────────────────────────────────────────────────────────────────────────────

locals {
  azure_vpn_enabled = var.azure_vpn_gateway_ip != "" && var.vpn_shared_key != ""
}

# Customer Gateway — Azure VPN Gateway 퍼블릭 IP를 AWS에 등록
resource "aws_customer_gateway" "azure" {
  count      = local.azure_vpn_enabled ? 1 : 0
  bgp_asn    = 65515
  ip_address = var.azure_vpn_gateway_ip
  type       = "ipsec.1"
  tags       = { Name = "ThreeTier-Azure-CGW" }
}

# VPN Connection — Main VPC VGW ↔ Azure CGW
# IKEv2 + AES256/SHA2-256/DHGroup14: Azure VpnGw1AZ 기본 정책과 매칭
resource "aws_vpn_connection" "azure" {
  count               = local.azure_vpn_enabled ? 1 : 0
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.azure[0].id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_preshared_key = var.vpn_shared_key
  tunnel2_preshared_key = var.vpn_shared_key

  tunnel1_ike_versions = ["ikev2"]
  tunnel2_ike_versions = ["ikev2"]

  tunnel1_phase1_encryption_algorithms = ["AES256"]
  tunnel2_phase1_encryption_algorithms = ["AES256"]
  tunnel1_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase1_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase1_dh_group_numbers      = [14]
  tunnel2_phase1_dh_group_numbers      = [14]

  tunnel1_phase2_encryption_algorithms = ["AES256"]
  tunnel2_phase2_encryption_algorithms = ["AES256"]
  tunnel1_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel2_phase2_integrity_algorithms  = ["SHA2-256"]
  tunnel1_phase2_dh_group_numbers      = [14]
  tunnel2_phase2_dh_group_numbers      = [14]

  tags = { Name = "ThreeTier-Azure-VPN" }
}

# Static Route: Azure VNet CIDR(10.2.0.0/16) → Main VPC via VPN
resource "aws_vpn_connection_route" "azure" {
  count                  = local.azure_vpn_enabled ? 1 : 0
  vpn_connection_id      = aws_vpn_connection.azure[0].id
  destination_cidr_block = "10.2.0.0/16"
}

output "vpn_azure_tunnel1_address" {
  description = "AWS 터널1 퍼블릭 IP → terraform-azure/terraform.tfvars aws_vpn_tunnel_ip에 입력"
  value       = local.azure_vpn_enabled ? aws_vpn_connection.azure[0].tunnel1_address : "VPN 미설정 (azure_vpn_gateway_ip/vpn_shared_key 입력 필요)"
  sensitive   = true
}

output "vpn_azure_tunnel2_address" {
  description = "AWS 터널2 퍼블릭 IP → terraform-azure/terraform.tfvars aws_vpn_tunnel2_ip에 입력"
  value       = local.azure_vpn_enabled ? aws_vpn_connection.azure[0].tunnel2_address : "VPN 미설정 (azure_vpn_gateway_ip/vpn_shared_key 입력 필요)"
  sensitive   = true
}
