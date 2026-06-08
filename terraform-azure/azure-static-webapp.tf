# 프론트엔드 이중화용 Static Web Apps. 다른 리소스와 의존성 없이 병렬로 구성 가능.
# Microsoft.Web/staticSites는 koreacentral을 지원하지 않아 별도 리전(var.static_web_app_location) 사용.

resource "azurerm_static_web_app" "frontend" {
  name                = "${var.project_prefix}-frontend"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.static_web_app_location

  sku_tier = "Free"
  sku_size = "Free"
}
