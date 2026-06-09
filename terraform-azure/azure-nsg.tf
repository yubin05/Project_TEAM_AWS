# 세부 인바운드/아웃바운드 규칙은 보안 파트와 협의 후 채울 예정.
# 우선 서브넷별 NSG 골격과 연동 관계만 정의해둔다.

resource "azurerm_network_security_group" "aca" {
  name                = "${var.project_prefix}-aca-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_group" "database" {
  name                = "${var.project_prefix}-db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "aca" {
  subnet_id                 = azurerm_subnet.aca.id
  network_security_group_id = azurerm_network_security_group.aca.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

# ACA 서브넷 → MySQL 3306 허용 (앱 → DB 트래픽)
resource "azurerm_network_security_rule" "allow_aca_mysql" {
  name                        = "allow-aca-mysql"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = "10.2.0.0/23"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database.name
}

# AWS VPC → MySQL 3306 허용 (DMS CDC 복제 — VPN Site-to-Site 경유)
resource "azurerm_network_security_rule" "allow_aws_dms_mysql" {
  name                        = "allow-aws-dms-mysql"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = "10.1.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database.name
}
