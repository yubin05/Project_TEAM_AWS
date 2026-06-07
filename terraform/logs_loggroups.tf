# ============================================================
# 내용: 로그 그룹 전체 통합 (ECS 제외 — ecs.tf에서 관리)
#   - CloudTrail / Lambda 3개 / API Gateway / WAF
# ============================================================

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/threetier"
  retention_in_days = 90

  tags = {
    Name    = "cloudtrail-log-group"
    Project = "threetier"
  }
}

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

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/threetier-http-api"
  retention_in_days = 30

  tags = {
    Name    = "apigateway-log-group"
    Project = "threetier"
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-threetier"
  retention_in_days = 30

  tags = {
    Name    = "waf-log-group"
    Project = "threetier"
  }
}