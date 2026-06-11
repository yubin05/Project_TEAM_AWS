
# ================================================================
# 파일 경로 : terraform/lambda.tf
# 용도      : booking-notification Lambda 함수 생성 + SQS 트리거 연결
# 선행 조건 : sqs.tf / iam_lambda.tf / ses.tf 모두 apply 완료
#             lambda/booking-notification/index.mjs 존재
# 수정 항목 : 없음
# ================================================================

# ──────────────────────────────────────────────
# 1. Lambda 배포용 zip 파일 참조
#    배포 zip은 수동으로 빌드해 커밋한다 (lambda_user_migration.tf 참고)
# ──────────────────────────────────────────────
locals {
  booking_notification_zip = "${path.module}/../lambda/booking-notification.zip"
}

# ──────────────────────────────────────────────
# 3. Lambda 함수 생성
# ──────────────────────────────────────────────
resource "aws_lambda_function" "booking_notification" {
  function_name = "ThreeTier-Booking-Notification"
  description   = "SQS booking-notification-queue 메시지 수신 → SES 예약 확인 이메일 발송"

  # zip 파일 참조 (수동 빌드된 정적 파일)
  filename         = local.booking_notification_zip
  # zip 내용이 바뀔 때만 Lambda를 업데이트 (불필요한 재배포 방지)
  source_code_hash = filebase64sha256(local.booking_notification_zip)

  # Node.js 20 런타임 — @aws-sdk/client-ses v3 기본 내장
  runtime = "nodejs20.x"
  # index.mjs 파일의 handler 함수를 진입점으로 지정
  handler = "index.handler"

  # iam_lambda.tf에서 생성한 Role 참조
  role = aws_iam_role.lambda_notification_role.arn

  # Lambda 최대 실행 시간
  # ⚠ sqs.tf의 visibility_timeout(40초)보다 반드시 작아야 함
  timeout = 30

  # 메모리 128MB — SES 이메일 발송만 하므로 충분
  memory_size = 128

  # ──────────────────────────────────────────────
  # 환경변수 — index.mjs에서 process.env로 읽는 값들
  # ──────────────────────────────────────────────
  environment {
    variables = {
      # ses.tf에서 생성한 이메일 Identity 참조
      FROM_EMAIL = aws_ses_email_identity.sender.email
    }
  }

  # CloudWatch Log Group이 먼저 생성된 후 Lambda 생성
  depends_on = [aws_cloudwatch_log_group.lambda_booking_notification]

  tags = {
    Name      = "ThreeTier-Booking-Notification"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 4. SQS → Lambda Event Source Mapping
#    SQS 큐를 Lambda의 트리거로 연결
#    AWS가 자동으로 SQS를 폴링하고 메시지가 있으면 Lambda 호출
# ──────────────────────────────────────────────
resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  # sqs.tf에서 생성한 본 큐 ARN 참조
  event_source_arn = aws_sqs_queue.booking_notification.arn
  function_name    = aws_lambda_function.booking_notification.arn

  # 한 번에 Lambda로 전달할 최대 메시지 수
  # 1로 설정 시 메시지 1개씩 처리 → 실패해도 다른 메시지에 영향 없음
  # 예약 이메일은 건별 처리가 맞으므로 1 권장
  batch_size = 1

  # true: 큐에 메시지 없으면 Lambda 대기 (비용 절감)
  # false: 큐가 비어있어도 즉시 반환
  enabled = true
}

# ──────────────────────────────────────────────
# 5. Outputs
# ──────────────────────────────────────────────
output "lambda_function_name" {
  description = "Lambda 함수 이름 (CloudWatch 로그 확인 시 사용)"
  value       = aws_lambda_function.booking_notification.function_name
}

output "lambda_function_arn" {
  description = "Lambda 함수 ARN"
  value       = aws_lambda_function.booking_notification.arn
}