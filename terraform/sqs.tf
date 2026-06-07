# ================================================================
# 파일 경로 : terraform/sqs.tf
# 용도      : 예약 알림용 SQS 큐 (booking-queue) + DLQ 생성
# 선행 조건 : 없음
# 수정 항목 : Queue Policy → iam_lambda.tf로 이동 (순환 참조 해소)
# ================================================================

# ──────────────────────────────────────────────
# 1. DLQ (Dead Letter Queue)
# ──────────────────────────────────────────────
resource "aws_sqs_queue" "booking_dlq" {
  name = "ThreeTier-Booking-Notification-DLQ"

  message_retention_seconds = 1209600 # 14일

  tags = {
    Name      = "ThreeTier-Booking-Notification-DLQ"
    ManagedBy = "terraform"
    Purpose   = "booking-notification-dead-letter"
  }
}

# ──────────────────────────────────────────────
# 2. 본 큐
# ──────────────────────────────────────────────
resource "aws_sqs_queue" "booking_notification" {
  name = "ThreeTier-Booking-Notification-Queue"

  visibility_timeout_seconds = 40    # Lambda timeout(30초) + 여유 10초
  message_retention_seconds  = 86400 # 1일
  receive_wait_time_seconds  = 20    # Long Polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.booking_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name      = "ThreeTier-Booking-Notification-Queue"
    ManagedBy = "terraform"
    Purpose   = "booking-notification"
  }
}

# ──────────────────────────────────────────────
# 3. Outputs
# ──────────────────────────────────────────────
output "booking_notification_queue_url" {
  description = "booking-service SQS_QUEUE_URL 환경변수 값"
  value       = aws_sqs_queue.booking_notification.url
}

output "booking_notification_queue_arn" {
  description = "Lambda Event Source Mapping ARN (lambda.tf 참조)"
  value       = aws_sqs_queue.booking_notification.arn
}

output "booking_dlq_arn" {
  description = "DLQ ARN (모니터링 알람용)"
  value       = aws_sqs_queue.booking_dlq.arn
}
# ============================================================
#  sqs.tf
#  애플리케이션 SQS 큐 정의
# ============================================================

# booking-service가 예약 이벤트를 push → Lambda가 consume → SES 이메일 발송
resource "aws_sqs_queue" "booking_queue" {
  name                       = "booking-queue"
  visibility_timeout_seconds = 300          # Lambda 처리 시간 고려 (5분)
  message_retention_seconds  = 86400        # 메시지 보관 1일
  receive_wait_time_seconds  = 20           # Long Polling (비용 절감)

  tags = { Name = "booking-queue" }
}

# review-service가 리뷰 이벤트를 push → hotel-service가 consume → 평점 갱신
resource "aws_sqs_queue" "rating_queue" {
  name                       = "rating-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  tags = { Name = "rating-queue" }
}
