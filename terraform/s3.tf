# ── 파일 업로드 버킷 (문의 첨부파일) ──────────────────────────────────────────
resource "aws_s3_bucket" "uploads" {
  bucket        = "threetier-uploads-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "ThreeTier-Uploads" }
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    id     = "delete-old-uploads"
    status = "Enabled"
    filter {}
    expiration { days = 180 }
  }
}

resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
  }
}

# ── 호텔 이미지 업로드 → Lambda 썸네일 리사이즈 트리거 ──────────────────────
# hotels/original/ prefix에 파일이 올라올 때만 Lambda 호출
# hotels/thumbnails/ 에 저장해도 이벤트 발생 안 함 → 무한루프 방지
resource "aws_s3_bucket_notification" "image_upload_trigger" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resize.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "hotels/original/"
  }

  # Lambda 리소스 정책(aws_lambda_permission)이 먼저 생성되어야 함
  depends_on = [aws_lambda_permission.allow_s3_invoke_image_resize]
}
