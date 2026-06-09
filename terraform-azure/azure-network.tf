resource "azurerm_virtual_network" "main" {
  name                = "${var.project_prefix}-vnet"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Azure Container Apps 환경이 위치할 서브넷 (전용 서브넷 위임 필요)
resource "azurerm_subnet" "aca" {
  name                 = "${var.project_prefix}-aca-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.aca_subnet_address_prefixes

  delegation {
    name = "aca-delegation"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Azure VPN Gateway 전용 서브넷 (이름 반드시 GatewaySubnet 고정)
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.2.4.0/27"]
}

# Azure Database for MySQL Flexible Server가 위치할 서브넷 (전용 서브넷 위임 필요)
resource "azurerm_subnet" "database" {
  name                 = "${var.project_prefix}-db-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = var.database_subnet_address_prefixes

  delegation {
    name = "mysql-delegation"

    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
