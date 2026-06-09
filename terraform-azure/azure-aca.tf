resource "azurerm_container_app_environment" "main" {
  name                     = "${var.project_prefix}-aca-env"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  infrastructure_subnet_id = azurerm_subnet.aca.id

  # infrastructure_resource_group_name은 Azure가 생성 시 자동 배정(ME_... 접두사)하는 값이라
  # 설정하지 않으면 plan마다 null과의 차이로 매번 재생성(replace)되는 것으로 잡힘 — 드리프트 무시 처리
  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}

# 마이크로서비스 5개(auth/hotel/booking/review/support) 정의(azurerm_container_app)는
# CI/CD 파트의 ACR 이미지 태그/네이밍 규칙이 확정된 뒤 추가 예정
locals {
  services = ["auth-service", "hotel-service", "booking-service", "review-service", "support-service"]
}

resource "azurerm_container_app" "services" {
  for_each = toset(local.services)

  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = "system"
  }

  template {
    container {
      name   = each.key
      image  = "${azurerm_container_registry.main.login_server}/${each.key}:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }

  # GitHub Actions가 이미지를 업데이트하면 Terraform이 되돌리지 않도록
  lifecycle {
    ignore_changes = [template]
  }
}
