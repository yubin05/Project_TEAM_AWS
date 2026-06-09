# ============================================================
# 포함 내용:
#   1. Lambda 함수 코드 ZIP 패키징
#   2. Lambda 함수 (slack-notifier)
#   3. Lambda IAM Role + Policy (최소 권한)
#   4. SNS → Lambda 구독 + 호출 권한
#   5. variables.tf 추가 변수 안내 (하단 주석 참고)
#
# 사전 조건:
#   - logs_alarms.tf 의 aws_sns_topic.alerts 가 먼저 생성되어야 함
#   - lambda/ 폴더에 slack_notifier.js 파일 존재해야 함
#   - terraform.tfvars 에 slack_webhook_url 값 설정 필요
# ============================================================


# ── 1. Lambda 함수 코드 ZIP 패키징 ─────────────────────────────────────────────
# terraform/ 기준 상위 폴더의 lambda/slack_notifier.js 를 ZIP으로 묶음
data "archive_file" "slack_notifier" {
  type        = "zip"
  source_file = "${path.module}/../lambda/slack_notifier.js"
  output_path = "${path.module}/../lambda/slack_notifier.zip"
}


# IAM 역할: iam.tf 에서 관리 (aws_iam_role.slack_notifier_lambda)

# ── 2. Lambda 함수 ────────────────────────────────────────────────────────────
resource "aws_lambda_function" "slack_notifier" {
  function_name    = "slack-notifier"
  description      = "CloudWatch 알람 → SNS → Slack #배포 채널 알림 전송"
  role             = aws_iam_role.slack_notifier_lambda.arn
  handler          = "slack_notifier.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.slack_notifier.output_path
  source_code_hash = data.archive_file.slack_notifier.output_base64sha256
  timeout          = 10   # Slack API 응답 대기 여유분
  memory_size      = 128  # 최소 사양으로 충분

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }

  tags = { Name = "slack-notifier" }
}

# 로그 그룹: logs_loggroups.tf 에서 관리 (aws_cloudwatch_log_group.slack_notifier)

# ── 3. SNS → Lambda 연결 ─────────────────────────────────────────────────────
# SNS가 Lambda를 호출할 수 있도록 권한 부여
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notifier.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.alerts.arn
}

# SNS Topic → Lambda 구독 등록
resource "aws_sns_topic_subscription" "slack_lambda" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notifier.arn
}


# ── 5. Outputs ────────────────────────────────────────────────────────────────
output "slack_notifier_lambda_arn" {
  description = "Slack 알람 Lambda ARN"
  value       = aws_lambda_function.slack_notifier.arn
}


# ============================================================
# ⚠️  variables.tf 에 아래 변수 2개 추가 필요
# ============================================================
#
# variable "slack_webhook_url" {
#   description = "Slack Incoming Webhook URL (#배포 채널)"
#   type        = string
#   sensitive   = true
#   default     = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# }
#
# variable "alert_email" {
#   description = "CloudWatch 알람 수신 이메일 (SNS 이메일 구독용)"
#   type        = string
#   default     = "your-email@example.com"
# }
#
# terraform.tfvars 에는 실제 값 입력:
#   slack_webhook_url = "https://hooks.slack.com/services/T.../B.../xxx"
#   alert_email       = "hyewon@gmail.com"
# ============================================================
