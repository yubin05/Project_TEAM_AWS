# AWS API Gateway(HTTP API + VPC Link → ALB)에 대응되는 통합 진입점.
# Active-Active 구조에서 Route 53/Traffic Manager가 클라우드당 단일 엔드포인트를
# 기준으로 라우팅하므로, ACA 서비스별 개별 ingress 대신 APIM으로 묶는다.

resource "azurerm_api_management" "main" {
  # "threetier-dr-apim"이 Azure 백엔드에 소프트 삭제 상태(고아 상태)로 남아 충돌 발생 — 새 이름으로 우회
  name                = "${var.project_prefix}-apim-v2"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  publisher_name  = var.apim_publisher_name
  publisher_email = var.apim_publisher_email

  # Consumption: 사용량 기반 과금, DR 보조 인프라 용도에 적합 (상시 인스턴스 비용 없음)
  sku_name = "Consumption_0"
}

# 서비스별 API/백엔드 정의(auth/hotel/booking/review/support)는
# ACA 서비스(azurerm_container_app) 5개의 엔드포인트가 확정된 뒤 추가 예정.
# AWS 쪽 라우트 구성(apigateway.tf)과 동일하게 경로 기준으로 각 ACA 서비스에 매핑.
