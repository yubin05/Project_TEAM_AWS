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

# AWS API Gateway 라우트와 동일하게 서비스별 개별 operation 정의
# params: url_template 내 {param} 목록 — APIM ValidationError 방지를 위해 명시 필요
locals {
  apim_operations = {
    # ── auth-service ────────────────────────────────────────────────
    "auth-login"             = { method = "POST",   path = "/auth/login",                      params = [] }
    "auth-register"          = { method = "POST",   path = "/auth/register",                   params = [] }
    "auth-profile-get"       = { method = "GET",    path = "/auth/profile",                    params = [] }
    "auth-profile-put"       = { method = "PUT",    path = "/auth/profile",                    params = [] }
    "auth-password"          = { method = "PUT",    path = "/auth/password",                   params = [] }
    # ── hotel-service ────────────────────────────────────────────────
    "hotels-featured"        = { method = "GET",    path = "/hotels/featured",                 params = [] }
    "hotels-regions"         = { method = "GET",    path = "/hotels/regions",                  params = [] }
    "hotels-search"          = { method = "GET",    path = "/hotels/search",                   params = [] }
    "hotels-list"            = { method = "GET",    path = "/hotels",                          params = [] }
    "hotels-detail"          = { method = "GET",    path = "/hotels/{id}",                     params = ["id"] }
    "hotels-room-detail"     = { method = "GET",    path = "/hotels/{hotelId}/rooms/{roomId}", params = ["hotelId", "roomId"] }
    "hotels-video-status"    = { method = "GET",    path = "/hotels/{id}/video-status",        params = ["id"] }
    "hotels-mine"            = { method = "GET",    path = "/hotels/mine",                     params = [] }
    "hotels-create"          = { method = "POST",   path = "/hotels",                          params = [] }
    "hotels-update"          = { method = "PUT",    path = "/hotels/{id}",                     params = ["id"] }
    "hotels-room-create"     = { method = "POST",   path = "/hotels/{hotelId}/rooms",          params = ["hotelId"] }
    "hotels-image-upload"    = { method = "POST",   path = "/hotels/{id}/image-upload-url",    params = ["id"] }
    "hotels-video-upload"    = { method = "POST",   path = "/hotels/{id}/video-upload-url",    params = ["id"] }
    "hotels-video-url"       = { method = "POST",   path = "/hotels/{id}/video-url",           params = ["id"] }
    "wishlist-toggle"        = { method = "POST",   path = "/wishlist/{hotelId}",              params = ["hotelId"] }
    "wishlist-get"           = { method = "GET",    path = "/wishlist",                        params = [] }
    "recommend"              = { method = "POST",   path = "/recommend",                       params = [] }
    # ── booking-service ──────────────────────────────────────────────
    "bookings-create"        = { method = "POST",   path = "/bookings",                        params = [] }
    "bookings-host"          = { method = "GET",    path = "/bookings/host",                   params = [] }
    "bookings-list"          = { method = "GET",    path = "/bookings",                        params = [] }
    "bookings-detail"        = { method = "GET",    path = "/bookings/{id}",                   params = ["id"] }
    "bookings-cancel"        = { method = "DELETE", path = "/bookings/{id}",                   params = ["id"] }
    # ── review-service ───────────────────────────────────────────────
    "hotel-reviews-list"     = { method = "GET",    path = "/hotels/{hotelId}/reviews",        params = ["hotelId"] }
    "reviews-create"         = { method = "POST",   path = "/reviews",                         params = [] }
    "reviews-delete"         = { method = "DELETE", path = "/reviews/{id}",                    params = ["id"] }
    # ── support-service ──────────────────────────────────────────────
    "notices-list"           = { method = "GET",    path = "/notices",                         params = [] }
    "inquiries-presign"      = { method = "POST",   path = "/inquiries/presign",               params = [] }
    "inquiries-create"       = { method = "POST",   path = "/inquiries",                       params = [] }
    "inquiries-list"         = { method = "GET",    path = "/inquiries",                       params = [] }
    "inquiries-delete"       = { method = "DELETE", path = "/inquiries/{id}",                  params = ["id"] }
    "inquiries-admin-list"   = { method = "GET",    path = "/admin/inquiries",                 params = [] }
    "inquiries-admin-answer" = { method = "PUT",    path = "/admin/inquiries/{id}/answer",     params = ["id"] }
    "support-chat"           = { method = "POST",   path = "/chat",                            params = [] }
  }
}

resource "azurerm_api_management_api_operation" "routes" {
  for_each = local.apim_operations

  operation_id        = each.key
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "${each.value.method} ${each.value.path}"
  method              = each.value.method
  url_template        = each.value.path

  dynamic "template_parameter" {
    for_each = each.value.params
    content {
      name     = template_parameter.value
      type     = "string"
      required = true
    }
  }
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

  depends_on = [azurerm_api_management_api_operation.routes]
}
