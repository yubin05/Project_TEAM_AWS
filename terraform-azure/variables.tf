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

# ── AWS ↔ Azure Site-to-Site VPN ─────────────────────────────────────────────
variable "aws_vpn_tunnel_ip" {
  description = "AWS VPN Connection 터널1 퍼블릭 IP (2차 AWS apply 후 출력값 입력). 입력 전까지 Azure Connection 생성 skip"
  type        = string
  default     = ""
}

variable "aws_vpn_tunnel2_ip" {
  description = "AWS VPN Connection 터널2 퍼블릭 IP (2차 AWS apply 후 출력값 입력). 입력 전까지 Azure Connection 생성 skip"
  type        = string
  default     = ""
}

variable "vpn_shared_key" {
  description = "IPsec 사전 공유 키 (AWS terraform.tfvars와 동일 값 사용)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_actions_sp_principal_id" {
  description = "GitHub Actions Service Principal의 Object ID (AcrPush 권한 부여용)"
  type        = string
  default     = "2563d59b-13d3-481d-aa59-68c4d9022a5a"
}

variable "aca_min_replicas" {
  description = "ACA 최소 레플리카 수 (DR 시나리오 콜드스타트 방지를 위해 0으로 두지 않음)"
  type        = number
  default     = 1
}

variable "aca_max_replicas" {
  description = "ACA 최대 레플리카 수"
  type        = number
  default     = 5
}

variable "aca_http_concurrent_requests" {
  description = "HTTP 스케일 아웃 기준 동시 요청 수"
  type        = number
  default     = 100
}
