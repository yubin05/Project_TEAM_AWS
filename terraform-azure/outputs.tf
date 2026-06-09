# ── VPN ──────────────────────────────────────────────────────────────────────
output "vpn_gateway_public_ip" {
  description = "Azure VPN Gateway 공인 IP → AWS terraform/main.tfvars의 azure_vpn_gateway_ip에 입력"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

# ── MySQL ─────────────────────────────────────────────────────────────────────
output "mysql_fqdn" {
  description = "Azure MySQL Flexible Server FQDN (VPN 경유 접속: mysql -h <fqdn> -u <user> -p)"
  value       = azurerm_mysql_flexible_server.main.fqdn
}

# ── APIM ──────────────────────────────────────────────────────────────────────
output "apim_gateway_url" {
  description = "Azure API Management 게이트웨이 URL"
  value       = azurerm_api_management.main.gateway_url
}

# ── ACR ───────────────────────────────────────────────────────────────────────
output "acr_login_server" {
  description = "Azure Container Registry 로그인 서버 (docker push/pull 시 사용)"
  value       = azurerm_container_registry.main.login_server
}

# ── Static Web App ────────────────────────────────────────────────────────────
output "static_web_app_url" {
  description = "Azure Static Web App 프론트엔드 URL"
  value       = "https://${azurerm_static_web_app.frontend.default_host_name}"
}

# ── Blob Storage ──────────────────────────────────────────────────────────────
output "blob_storage_endpoint" {
  description = "Azure Blob Storage 엔드포인트"
  value       = azurerm_storage_account.uploads.primary_blob_endpoint
}

# ── ACA ───────────────────────────────────────────────────────────────────────
output "aca_environment_name" {
  description = "Container App Environment 이름 (ACA 배포 시 사용)"
  value       = azurerm_container_app_environment.main.name
}
