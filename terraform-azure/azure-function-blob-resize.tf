# ================================================================
# AWS image-resize Lambda의 Azure 대응판.
# AWS 장애(Azure Active) 중 hotels 컨테이너 original/ 업로드 → thumbnails/ 리사이즈.
#
# 코드: azure-functions/blob-resize/
# 빌드 (zip, node_modules 제외 — SCM_DO_BUILD_DURING_DEPLOYMENT=true가 Azure에서 npm install 수행):
#   cd azure-functions/blob-resize
#   Compress-Archive -Path host.json,package.json,src -DestinationPath ../blob-resize.zip -Force
#
# 배포는 아래 zip_deploy_file로 terraform apply 시 자동 처리됨.
# 단, 코드만 바뀌고 경로/파일명이 같으면 terraform이 변경을 감지 못하므로
# 재배포가 필요하면: terraform apply -replace="azurerm_linux_function_app.blob_resize"
# ================================================================

resource "azurerm_service_plan" "blob_resize" {
  name                = "${var.project_prefix}-blob-resize-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "blob_resize" {
  name                = "${var.project_prefix}-blob-resize"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.uploads.name
  storage_account_access_key = azurerm_storage_account.uploads.primary_access_key
  service_plan_id            = azurerm_service_plan.blob_resize.id

  zip_deploy_file = "${path.module}/../azure-functions/blob-resize.zip"

  site_config {
    application_stack {
      node_version = "20"
    }
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME       = "node"
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    THUMBNAIL_WIDTH                = "400"
    THUMBNAIL_HEIGHT               = "300"
  }
}
