# ============================================================
# 내용: 로그 그룹 전체 통합
#   - ECS 5개 / CloudTrail / Lambda 8개 / API Gateway / WAF
#   - VPC Flow Logs / Slack Notifier / DMS / RDS 3개
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

resource "aws_cloudwatch_log_group" "lambda_s3_blob_sync" {
  name              = "/aws/lambda/ThreeTier-S3-Blob-Sync"
  retention_in_days = 30

  tags = {
    Name      = "ThreeTier-S3-Blob-Sync-Logs"
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

# ── API Gateway ──────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/threetier-http-api"
  retention_in_days = 30
  tags              = { Name = "ThreeTier-APIGW-LogGroup" }
}

# ── Lambda (Cognito / ALB) ────────────────────────────────────
resource "aws_cloudwatch_log_group" "pre_token_generation" {
  name              = "/aws/lambda/ThreeTier-Pre-Token-Generation"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "user_migration" {
  name              = "/aws/lambda/ThreeTier-User-Migration"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "post_authentication" {
  name              = "/aws/lambda/ThreeTier-Post-Authentication"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "alb_log_processor" {
  name              = "/aws/lambda/threetier-alb-log-processor"
  retention_in_days = 14
  tags              = { Name = "alb-log-processor-log-group", Project = "threetier" }
}
