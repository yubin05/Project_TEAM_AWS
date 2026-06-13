# 프론트엔드 이중화용 Static Web Apps. 다른 리소스와 의존성 없이 병렬로 구성 가능.
# Microsoft.Web/staticSites는 koreacentral을 지원하지 않아 별도 리전(var.static_web_app_location) 사용.

resource "azurerm_static_web_app" "frontend" {
  name                = "${var.project_prefix}-frontend"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.static_web_app_location

  sku_tier = "Free"
  sku_size = "Free"
}

# www.vundle34.cloud DR failover 대상 (Route53 CNAME secondary).
# CNAME-delegation 검증 방식이라 적용 시점에 Route53의 www CNAME이
# 이 Static Web App의 default_host_name을 가리키고 있어야 검증/인증서 발급이 된다.
resource "azurerm_static_web_app_custom_domain" "frontend" {
  static_web_app_id = azurerm_static_web_app.frontend.id
  domain_name       = "www.vundle34.cloud"
  validation_type   = "cname-delegation"
}
