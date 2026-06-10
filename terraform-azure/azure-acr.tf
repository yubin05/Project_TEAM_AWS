resource "azurerm_container_registry" "main" {
  name                = "${replace(var.project_prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"

  # Admin 계정 대신 RBAC(역할 할당)으로 접근 제어 — 보안 파트와 협의
  admin_enabled = false
}

# ACR 권한(Push/Pull) RBAC 할당은 CI/CD 파트의 Service Principal/Managed Identity가
# 정해진 뒤 azurerm_role_assignment로 추가 예정
resource "azurerm_role_assignment" "aca_acr_pull" {
  for_each = local.all_container_apps

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = each.value.identity[0].principal_id
}

resource "azurerm_role_assignment" "sp_acr_push" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = var.github_actions_sp_principal_id
}
