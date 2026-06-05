# ================================================================
# 파일 경로 : terraform/iam_lambda.tf
# 용도      : Lambda 실행 IAM Role + 권한 Policy + SQS Queue Policy 생성
# 선행 조건 : sqs.tf 생성 완료 (SQS ARN 참조)
# 수정 항목 : aws_sqs_queue_policy 추가 (sqs.tf에서 이동 — 순환 참조 해소)
# ================================================================

# ──────────────────────────────────────────────
# 1. Trust Policy — Lambda만 이 Role 사용 가능
# ──────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ──────────────────────────────────────────────
# 2. Lambda Execution Role
# ──────────────────────────────────────────────
resource "aws_iam_role" "lambda_notification_role" {
  name               = "ThreeTier-Lambda-Notification-Role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name      = "ThreeTier-Lambda-Notification-Role"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 3. 권한 Policy 정의
# ──────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_notification_policy" {

  # ① CloudWatch Logs
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:ap-northeast-2:*:log-group:/aws/lambda/ThreeTier-Booking-Notification:*"
    ]
  }

  # ② SQS 본 큐 — 메시지 수신 & 삭제
  statement {
    sid    = "AllowSQSConsume"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.booking_notification.arn
    ]
  }

  # ③ SQS DLQ — 속성 조회 (모니터링용)
  statement {
    sid    = "AllowDLQRead"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [
      aws_sqs_queue.booking_dlq.arn
    ]
  }

  # ④ SES — 이메일 발송
  statement {
    sid    = "AllowSESSend"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = [aws_ses_email_identity.sender.arn]
  }
}

# ──────────────────────────────────────────────
# 4. Policy 문서 → 실제 IAM Policy 리소스
# ──────────────────────────────────────────────
resource "aws_iam_policy" "lambda_notification_policy" {
  name        = "ThreeTier-Lambda-Notification-Policy"
  description = "ThreeTier booking-notification Lambda 최소 권한"
  policy      = data.aws_iam_policy_document.lambda_notification_policy.json

  tags = {
    Name      = "ThreeTier-Lambda-Notification-Policy"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 5. Role에 Policy 부착
# ──────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "lambda_notification" {
  role       = aws_iam_role.lambda_notification_role.name
  policy_arn = aws_iam_policy.lambda_notification_policy.arn
}

# ──────────────────────────────────────────────
# 6. Output
# ──────────────────────────────────────────────
output "lambda_notification_role_arn" {
  description = "Lambda 함수 생성 시 role에 지정할 ARN (lambda.tf 참조)"
  value       = aws_iam_role.lambda_notification_role.arn
}

# ──────────────────────────────────────────────
# 7. SQS Queue Policy
#    Role(6번)과 Queue(sqs.tf)가 모두 만들어진 뒤에 Policy를 붙이는 구조
#    → sqs.tf에서 이동하여 순환 참조 해소
# ──────────────────────────────────────────────
resource "aws_sqs_queue_policy" "booking_notification" {
  queue_url = aws_sqs_queue.booking_notification.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # TODO: ecs.tf에서 aws_iam_role.ecs_task 주석 해제 후 아래 블록 주석 해제
      # {
      #   Sid    = "AllowECSBookingServiceSend"
      #   Effect = "Allow"
      #   Principal = {
      #     AWS = aws_iam_role.ecs_task.arn
      #   }
      #   Action   = "sqs:SendMessage"
      #   Resource = aws_sqs_queue.booking_notification.arn
      # },
      {
        Sid    = "AllowLambdaConsume"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_notification_role.arn
        }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.booking_notification.arn
      }
    ]
  })
}