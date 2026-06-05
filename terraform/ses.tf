
# ================================================================
# 파일 경로 : terraform/ses.tf
# 용도      : SES 발신 이메일 Identity 등록 + 설정
# 선행 조건 : 없음 (독립적으로 생성 가능)
# 수정 항목 : aws_ses_email_identity.sender의 email 주소
# ================================================================

# ──────────────────────────────────────────────
# 1. SES 발신 이메일 Identity 등록
#    terraform apply 후 해당 이메일로 AWS 인증 메일이 발송됨
#    → 메일함에서 "Click to verify" 링크 클릭해야 실제 발송 가능
# ──────────────────────────────────────────────
resource "aws_ses_email_identity" "sender" {
  email = "kimkihyo18@naver.com"
}

# ──────────────────────────────────────────────
# 2. Output — lambda.tf에서 발신 이메일 주소 참조용
# ──────────────────────────────────────────────
output "ses_sender_email" {
  description = "Lambda 함수에서 SES_SENDER_EMAIL 환경변수로 주입할 값"
  value       = aws_ses_email_identity.sender.email
}

output "ses_sender_arn" {
  description = "iam_lambda.tf SES 권한 Resource 교체 시 사용할 ARN"
  value       = aws_ses_email_identity.sender.arn
}