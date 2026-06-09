# ============================================================
# 내용: 로그 그룹 전체 통합
#   - ECS 5개 / CloudTrail / Lambda 4개 / API Gateway / WAF
#   - VPC Flow Logs / Slack Notifier
# ============================================================

# ── ECS 서비스 로그 그룹 ─────────────────────────────────────
resource "aws_cloudwatch_log_group" "auth" {
  name              = "/ecs/auth-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "hotel" {
  name              = "/ecs/hotel-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "booking" {
  name              = "/ecs/booking-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "review" {
  name              = "/ecs/review-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "support" {
  name              = "/ecs/support-service"
  retention_in_days = 30
}

# ── CloudTrail ───────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/threetier"
  retention_in_days = 90

  tags = {
    Name    = "cloudtrail-log-group"
    Project = "threetier"
  }
}

# ── Lambda ───────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda_booking_notification" {
  name              = "/aws/lambda/ThreeTier-Booking-Notification"
  retention_in_days = 30

  tags = {
    Name      = "ThreeTier-Booking-Notification-Logs"
    ManagedBy = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "lambda_image_resize" {
  name              = "/aws/lambda/ThreeTier-Image-Resize"
  retention_in_days = 30

  tags = {
    Name      = "ThreeTier-Image-Resize-Logs"
    ManagedBy = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "lambda_cognito_post_confirm" {
  name              = "/aws/lambda/cognito-post-confirm"
  retention_in_days = 30

  tags = {
    Name    = "lambda-cognito-post-confirm-log-group"
    Project = "threetier"
  }
}

resource "aws_cloudwatch_log_group" "lambda_cw_transform" {
  name              = "/aws/lambda/threetier-cw-log-transform"
  retention_in_days = 14

  tags = { Name = "lambda-cw-transform-log-group", Project = "threetier" }
}

# ── WAF ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-threetier"
  retention_in_days = 30

  tags = {
    Name    = "waf-log-group"
    Project = "threetier"
  }
}

# ── VPC Flow Logs ────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/threetier/vpc-flow-logs"
  retention_in_days = 30

  tags = { Name = "vpc-flow-logs-group", Project = "threetier" }
}

# ── Slack Notifier ───────────────────────────────────────────
resource "aws_cloudwatch_log_group" "slack_notifier" {
  name              = "/aws/lambda/slack-notifier"
  retention_in_days = 30
}

# ── DMS 태스크 로그 ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "dms_task" {
  name              = "/aws/dms/tasks/my-migration-task"
  retention_in_days = 30
  tags              = { Name = "dms-task-log-group", Project = "threetier" }
}

# ── RDS Aurora 로그 ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "rds_error" {
  count             = var.enable_rds_log_groups ? 1 : 0
  name              = "/aws/rds/cluster/threetier-aurora-cluster/error"
  retention_in_days = 30
  tags              = { Name = "rds-error-log-group", Project = "threetier" }
}

resource "aws_cloudwatch_log_group" "rds_general" {
  count             = var.enable_rds_log_groups ? 1 : 0
  name              = "/aws/rds/cluster/threetier-aurora-cluster/general"
  retention_in_days = 14
  tags              = { Name = "rds-general-log-group", Project = "threetier" }
}

resource "aws_cloudwatch_log_group" "rds_slowquery" {
  count             = var.enable_rds_log_groups ? 1 : 0
  name              = "/aws/rds/cluster/threetier-aurora-cluster/slowquery"
  retention_in_days = 30
  tags              = { Name = "rds-slowquery-log-group", Project = "threetier" }
}
