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

# TODO (보안 파트 협의 후 추가):
# - DB NSG: ACA 서브넷 → MySQL 포트(3306)만 허용, 그 외 인바운드 차단
# - DMS 복제 인스턴스 ↔ Azure DB 간 경로 (퍼블릭+TLS vs Private Endpoint/VPN)에 따른 규칙
