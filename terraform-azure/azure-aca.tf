resource "azurerm_container_app_environment" "main" {
  name                     = "${var.project_prefix}-aca-env"
  location                 = azurerm_resource_group.main.location
  resource_group_name      = azurerm_resource_group.main.name
  infrastructure_subnet_id = azurerm_subnet.aca.id

  lifecycle {
    ignore_changes = [infrastructure_resource_group_name]
  }
}

resource "azurerm_container_app" "auth_service" {
  name                         = "auth-service"
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

  ingress {
    external_enabled = true
    target_port      = 3001
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.aca_min_replicas
    max_replicas = var.aca_max_replicas

    container {
      name   = "auth-service"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = var.aca_http_concurrent_requests
    }
  }

  lifecycle {
    ignore_changes = [template, workload_profile_name]
  }
}

resource "azurerm_container_app" "hotel_service" {
  name                         = "hotel-service"
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

  ingress {
    external_enabled = true
    target_port      = 3002
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  secret {
    name  = "azure-storage-key"
    value = azurerm_storage_account.uploads.primary_access_key
  }

  template {
    min_replicas = var.aca_min_replicas
    max_replicas = var.aca_max_replicas

    container {
      name   = "hotel-service"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      # AWS 장애 시 Azure Active 상태에서 호텔 이미지 업로드를 Azure Blob SAS로 처리하기 위한 설정
      # ignore_changes = [template] 때문에 기존 Container App에는 적용되지 않으며,
      # 대신 .github/workflows/deploy-backend.yml의 hotel-service 배포 단계에서
      # 매 배포마다 az containerapp update --set-env-vars로 설정함 (여기서는 초기 생성 시 기본값)
      env {
        name  = "APP_MODE"
        value = "azure"
      }
      env {
        name  = "AZURE_STORAGE_ACCOUNT"
        value = azurerm_storage_account.uploads.name
      }
      env {
        name        = "AZURE_STORAGE_KEY"
        secret_name = "azure-storage-key"
      }
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = var.aca_http_concurrent_requests
    }
  }

  lifecycle {
    ignore_changes = [template, workload_profile_name]
  }

  depends_on = [azurerm_container_app.auth_service]
}

resource "azurerm_container_app" "booking_service" {
  name                         = "booking-service"
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

  ingress {
    external_enabled = true
    target_port      = 3003
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.aca_min_replicas
    max_replicas = var.aca_max_replicas

    container {
      name   = "booking-service"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = var.aca_http_concurrent_requests
    }
  }

  lifecycle {
    ignore_changes = [template, workload_profile_name]
  }

  depends_on = [azurerm_container_app.hotel_service]
}

resource "azurerm_container_app" "review_service" {
  name                         = "review-service"
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

  ingress {
    external_enabled = true
    target_port      = 3004
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.aca_min_replicas
    max_replicas = var.aca_max_replicas

    container {
      name   = "review-service"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = var.aca_http_concurrent_requests
    }
  }

  lifecycle {
    ignore_changes = [template, workload_profile_name]
  }

  depends_on = [azurerm_container_app.booking_service]
}

resource "azurerm_container_app" "support_service" {
  name                         = "support-service"
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

  ingress {
    external_enabled = true
    target_port      = 3005
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.aca_min_replicas
    max_replicas = var.aca_max_replicas

    container {
      name   = "support-service"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    http_scale_rule {
      name                = "http-scaling"
      concurrent_requests = var.aca_http_concurrent_requests
    }
  }

  lifecycle {
    ignore_changes = [template, workload_profile_name]
  }

  depends_on = [azurerm_container_app.review_service]
}

# azure-acr.tf의 for_each에서 참조하는 map
locals {
  all_container_apps = {
    "auth-service"    = azurerm_container_app.auth_service
    "hotel-service"   = azurerm_container_app.hotel_service
    "booking-service" = azurerm_container_app.booking_service
    "review-service"  = azurerm_container_app.review_service
    "support-service" = azurerm_container_app.support_service
  }
}
