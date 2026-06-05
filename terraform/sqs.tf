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
