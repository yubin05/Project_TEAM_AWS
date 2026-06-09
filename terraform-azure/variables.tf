variable "azure_subscription_id" {
  description = "Azure 구독 ID"
  type        = string
}

variable "resource_group_name" {
  description = "리소스 그룹 이름"
  type        = string
  default     = "threetier-dr-rg"
}

variable "location" {
  description = "Azure 리전"
  type        = string
  default     = "koreacentral"
}

variable "project_prefix" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "threetier-dr"
}

variable "vnet_address_space" {
  description = "VNet CIDR"
  type        = list(string)
  default     = ["10.2.0.0/16"]
}

variable "aca_subnet_address_prefixes" {
  description = "ACA 서브넷 CIDR"
  type        = list(string)
  # /23은 512개 주소 경계에 정렬되어야 함 (세 번째 옥텟이 짝수)
  default = ["10.2.0.0/23"]
}

variable "static_web_app_location" {
  description = "Static Web Apps 리전 (Microsoft.Web/staticSites는 koreacentral 미지원 — 가장 가까운 지원 리전 사용)"
  type        = string
  default     = "eastasia"
}

variable "database_subnet_address_prefixes" {
  description = "DB 서브넷 CIDR"
  type        = list(string)
  default     = ["10.2.3.0/24"]
}

variable "apim_publisher_name" {
  description = "API Management 게시자 이름"
  type        = string
}

variable "apim_publisher_email" {
  description = "API Management 게시자 이메일"
  type        = string
}

variable "db_admin_username" {
  description = "Azure Database for MySQL 관리자 계정"
  type        = string
  sensitive   = true
}

variable "db_admin_password" {
  description = "Azure Database for MySQL 관리자 비밀번호"
  type        = string
  sensitive   = true
}

variable "github_actions_sp_principal_id" {
  description = "GitHub Actions Service Principal의 Object ID (AcrPush 권한 부여용)"
  type        = string
  default     = "2563d59b-13d3-481d-aa59-68c4d9022a5a"
}
