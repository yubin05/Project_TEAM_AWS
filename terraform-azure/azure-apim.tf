resource "azurerm_api_management" "main" {
  name                = "${var.project_prefix}-apim-v2"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  publisher_name  = var.apim_publisher_name
  publisher_email = var.apim_publisher_email

  sku_name = "Consumption_0"
}

# 단일 통합 API — 경로별 라우팅은 인바운드 정책의 choose 블록에서 처리
resource "azurerm_api_management_api" "main" {
  name                  = "sponge-trip-api"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Sponge Trip API"
  path                  = ""
  protocols             = ["https"]
  subscription_required = false
}

# 각 HTTP 메서드별 catch-all 오퍼레이션
resource "azurerm_api_management_api_operation" "catchall" {
  for_each = toset(["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"])

  operation_id        = "catchall-${lower(each.key)}"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Catch-all ${each.key}"
  method              = each.key
  url_template        = "/*"
}

# CORS + 경로 기반 백엔드 라우팅 정책
resource "azurerm_api_management_api_policy" "main" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        <cors allow-credentials="true">
          <allowed-origins>
            <origin>https://calm-plant-04a6be700.7.azurestaticapps.net</origin>
            <origin>https://www.vundle34.cloud</origin>
            <origin>http://localhost:3000</origin>
          </allowed-origins>
          <allowed-methods preflight-result-max-age="300">
            <method>*</method>
          </allowed-methods>
          <allowed-headers>
            <header>*</header>
          </allowed-headers>
          <expose-headers>
            <header>*</header>
          </expose-headers>
        </cors>
        <choose>
          <when condition="@(context.Request.OriginalUrl.Path.StartsWith("/auth"))">
            <set-backend-service base-url="https://${azurerm_container_app.auth_service.ingress[0].fqdn}" />
          </when>
          <when condition="@(context.Request.OriginalUrl.Path.Contains("/reviews"))">
            <set-backend-service base-url="https://${azurerm_container_app.review_service.ingress[0].fqdn}" />
          </when>
          <when condition="@(context.Request.OriginalUrl.Path.StartsWith("/hotels") || context.Request.OriginalUrl.Path.StartsWith("/wishlist") || context.Request.OriginalUrl.Path.StartsWith("/recommend"))">
            <set-backend-service base-url="https://${azurerm_container_app.hotel_service.ingress[0].fqdn}" />
          </when>
          <when condition="@(context.Request.OriginalUrl.Path.StartsWith("/bookings"))">
            <set-backend-service base-url="https://${azurerm_container_app.booking_service.ingress[0].fqdn}" />
          </when>
          <otherwise>
            <set-backend-service base-url="https://${azurerm_container_app.support_service.ingress[0].fqdn}" />
          </otherwise>
        </choose>
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
  XML

  depends_on = [azurerm_api_management_api_operation.catchall]
}
