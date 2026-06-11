variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "key_name" {
  description = "EC2 KeyPair 이름"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_client_id" {
  description = "Cognito App Client ID"
  type        = string
}

variable "github_token" {
  description = "GitHub Personal Access Token (repo 권한 필요) — Amplify 소스 연결용"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub 계정 ID (owner)"
  type        = string
  default     = "yubin05"
}

variable "github_repo_name" {
  description = "GitHub 저장소 이름"
  type        = string
  default     = "Project_TEAM_AWS"
}

variable "amplify_force_deploy" {
  description = "강제 배포 시 true (AMPLIFY_DIFF_DEPLOY 비활성화)"
  type        = bool
  default     = true
}

variable "db_password" {
  description = "RDS MySQL 관리자 비밀번호"
  type        = string
  sensitive   = true
}

variable "github_connection_uuid" {
  description = "CodeConnections GitHub 연결 UUID (콘솔 → CodePipeline → Settings → Connections에서 확인)"
  type        = string
}

variable "deploy_branch" {
  description = "CodePipeline/Amplify가 감지할 Git 브랜치"
  type        = string
  default     = "main"
}

variable "enable_cloudtrail" {
  description = "CloudTrail 리소스 terraform 관리 여부. 콘솔에서 수동 생성한 경우 false"
  type        = bool
  default     = false
}

variable "enable_rds_log_groups" {
  description = "RDS Aurora 로그 그룹 terraform 관리 여부"
  type        = bool
  default     = true
}

variable "enable_migration" {
  description = "MySQL EC2 + DMS 리소스 활성화. 최초 배포 시 true, 마이그레이션 완료 후 false로 바꾸고 apply하면 자동 삭제"
  type        = bool
  default     = true
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL (#배포 채널)"
  type        = string
  sensitive   = true
  default     = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}

variable "alert_email" {
  description = "CloudWatch 알람 수신 이메일 (SNS 이메일 구독용)"
  type        = string
  default     = "shw504@gmail.com"
}

variable "ses_sender_email" {
  description = "SES 발신 이메일 Identity 주소 (예약 알림 메일 발신자)"
  type        = string
  default     = "kimkihyo18@naver.com"
}

variable "opensearch_master_user" {
  description = "OpenSearch Dashboards 관리자 사용자 이름"
  type        = string
  default     = "os-admin"
}

variable "opensearch_master_password" {
  description = "OpenSearch Dashboards 관리자 비밀번호 (대소문자+숫자+특수문자 포함 8자 이상)"
  type        = string
  sensitive   = true
}

variable "opensearch_allowed_ips" {
  description = "OpenSearch 접근 허용 공인 IP 목록 (CIDR). terraform.tfvars에 팀원 IP 입력"
  type        = list(string)
  default     = []
}

variable "enable_opensearch_tunnel" {
  description = "OpenSearch Dashboards 접근용 SSM 터널 EC2 생성 여부. 대시보드 확인이 필요할 때만 true로 설정 (평소 false로 비용 절감)"
  type        = bool
  default     = true
}

# ── AWS ↔ Azure Site-to-Site VPN ─────────────────────────────────────────────
variable "azure_vpn_gateway_ip" {
  description = "Azure VPN Gateway 퍼블릭 IP (1차 azure apply 후 출력값 입력). 입력 전까지 AWS VPN 리소스 생성 skip"
  type        = string
  default     = "20.200.236.211"
}

variable "vpn_shared_key" {
  description = "IPsec 사전 공유 키 (8-64자, 영숫자·점·밑줄만 허용). Azure terraform.tfvars와 동일 값 사용"
  type        = string
  sensitive   = true
}

# ── Azure DR MySQL (CDC 타깃) ─────────────────────────────────────────────────
variable "azure_mysql_host" {
  description = "Azure MySQL Flexible Server 프라이빗 IP (VPN 경유 CDC 타깃). Azure 포털 → MySQL 서버 → 연결 문자열에서 확인"
  type        = string
  default     = "10.2.3.4"
}

variable "azure_mysql_user" {
  description = "Azure MySQL 관리자 계정 (DMS CDC 타깃 접속용)"
  type        = string
  default     = "dbadmin"
}

variable "azure_mysql_password" {
  description = "Azure MySQL 관리자 비밀번호"
  type        = string
  sensitive   = true
}