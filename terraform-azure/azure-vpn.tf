# ──────────────────────────────────────────────────────────────────────────────
# Azure ↔ AWS Site-to-Site VPN
#
# [적용 순서]
# 1단계: 이 파일만 포함해서 apply → output "vpn_gateway_public_ip" 확인
#        → terraform/terraform.tfvars에 azure_vpn_gateway_ip 입력 후 AWS apply
# 2단계: AWS output "vpn_tunnel1_address" 확인
#        → terraform-azure/terraform.tfvars에 aws_vpn_tunnel_ip 입력 후 재apply
#        → VPN 터널 UP
# ──────────────────────────────────────────────────────────────────────────────

# VPN Gateway용 고정 공인 IP (Standard SKU 필수)
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${var.project_prefix}-vpn-gw-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = { Name = "${var.project_prefix}-vpn-gw-pip" }
}

# Azure VPN Gateway (VpnGw1, RouteBased)
resource "azurerm_virtual_network_gateway" "main" {
  name                = "${var.project_prefix}-vpn-gateway"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  type          = "Vpn"
  vpn_type      = "RouteBased"
  sku           = "VpnGw1AZ"
  active_active = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = { Name = "${var.project_prefix}-vpn-gateway" }
}

# AWS 측 표현 (AWS VPN 터널 IP 입력 후 생성 — 2단계부터 활성화)
resource "azurerm_local_network_gateway" "aws" {
  count               = var.aws_vpn_tunnel_ip != "" ? 1 : 0
  name                = "${var.project_prefix}-aws-lgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  gateway_address     = var.aws_vpn_tunnel_ip
  address_space       = ["10.1.0.0/16"]
  tags                = { Name = "${var.project_prefix}-aws-lgw" }
}

resource "azurerm_virtual_network_gateway_connection" "to_aws" {
  count                      = var.aws_vpn_tunnel_ip != "" ? 1 : 0
  name                       = "${var.project_prefix}-conn-to-aws"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws[0].id
  shared_key                 = var.vpn_shared_key

  # AWS IKEv2 호환 암호화 설정 (vpn.tf tunnel 설정과 일치)
  ipsec_policy {
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    dh_group         = "DHGroup14"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS2048"
    sa_lifetime      = 27000
    sa_datasize      = 102400000
  }

  tags = { Name = "${var.project_prefix}-conn-to-aws" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "vpn_gateway_public_ip" {
  description = "Azure VPN Gateway 공인 IP → terraform/terraform.tfvars의 azure_vpn_gateway_ip에 입력"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}
