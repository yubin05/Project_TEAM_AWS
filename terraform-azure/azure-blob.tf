# AWS S3(uploads 버킷, hotels/ 경로 공개 읽기)에 대응되는 Azure Blob Storage.
# Storage Replication으로 S3 ↔ Blob 간 동기화 예정 (구체 방식은 로그/보안 파트와 협의)

resource "azurerm_storage_account" "uploads" {
  # Storage Account 이름은 Azure 전체에서 유일해야 함 — "threetierdruploads"는 이미 선점되어 있어 접미사 추가
  name                = "${replace(var.project_prefix, "-", "")}uploadsmain"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# AWS S3 uploads 버킷의 hotels/ 경로(공개 읽기)에 대응
resource "azurerm_storage_container" "hotels" {
  name                  = "hotels"
  storage_account_name  = azurerm_storage_account.uploads.name
  container_access_type = "blob"
}

# 문의 첨부파일 등 비공개 업로드 경로 — S3 uploads 버킷의 나머지 경로에 대응
resource "azurerm_storage_container" "uploads" {
  name                  = "uploads"
  storage_account_name  = azurerm_storage_account.uploads.name
  container_access_type = "private"
}
