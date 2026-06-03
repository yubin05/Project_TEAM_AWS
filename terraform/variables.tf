variable "key_name" {
  description = "EC2 KeyPair 이름"
  type        = string
}

variable "jwt_secret" {
  description = "JWT 시크릿 (모든 서비스 공유)"
  type        = string
  sensitive   = true
  default     = "change-me-jwt-secret-32chars"
}

variable "internal_secret" {
  description = "서비스 간 내부 통신 시크릿"
  type        = string
  sensitive   = true
  default     = "change-me-internal-secret"
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
  default     = false
}

variable "db_password" {
  description = "RDS MySQL 관리자 비밀번호"
  type        = string
  sensitive   = true
  default     = "Change-me-db-password1!"
}

variable "github_connection_uuid" {
  description = "CodeConnections GitHub 연결 UUID (콘솔 → CodePipeline → Settings → Connections에서 확인)"
  type        = string
}