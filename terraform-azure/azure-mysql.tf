# VNet 내부에서만 접근 가능한 프라이빗 액세스 구성 (퍼블릭 엔드포인트 미사용).
# delegated_subnet_id를 쓰는 프라이빗 모드는 Private DNS Zone 연결이 필수.
resource "azurerm_private_dns_zone" "mysql" {
  name                = "${var.project_prefix}.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.project_prefix}-mysql-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.main.id
}

resource "azurerm_mysql_flexible_server" "main" {
  name                = "${var.project_prefix}-mysql"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  administrator_login    = var.db_admin_username
  administrator_password = var.db_admin_password

  sku_name = "B_Standard_B1ms"
  version  = "8.0.21"

  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]

  # zone은 Azure가 자동 배정하며, 단독으로는 변경할 수 없어 plan마다 충돌이 날 수 있어 무시 처리
  lifecycle {
    ignore_changes = [zone]
  }

  # AWS DMS ongoing replication(CDC)의 복제 타겟으로 사용 예정 (RPO 5분 요구사항)
  # DMS 복제 인스턴스가 VNet 외부(AWS)에 있으므로, DMS↔Azure DB 간 경로(VPN/Private Link등)는
  # 보안 파트와 별도 조율 필요 — DB 자체는 퍼블릭 엔드포인트 없이 VNet 내부 접근만 허용
}

# MySQL 8.0.30+ 기본값(ON)인 invisible PK 컬럼(my_row_id) 자동 생성 비활성화.
# ON 상태면 DMS가 PK 없이 CREATE TABLE 후 별도 ALTER TABLE ADD PRIMARY KEY를 실행할 때
# "Multiple primary key defined"(1068) 에러로 모든 테이블이 Table error 상태가 됨.
resource "azurerm_mysql_flexible_server_configuration" "disable_invisible_pk" {
  name                = "sql_generate_invisible_primary_key"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "OFF"
}
