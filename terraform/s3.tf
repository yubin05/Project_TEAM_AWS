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

# ── MySQL EC2 user_data용 스크립트 (S3 VPC 엔드포인트로 다운로드) ──────────────
resource "aws_s3_object" "mysql_install" {
  count  = var.enable_migration ? 1 : 0
  bucket = aws_s3_bucket.uploads.bucket
  key    = "database/mysql_install.sh"
  source = "${path.module}/../database/scripts/mysql_install.sh"
  etag   = filemd5("${path.module}/../database/scripts/mysql_install.sh")
}

resource "aws_s3_object" "run_seed" {
  count  = var.enable_migration ? 1 : 0
  bucket = aws_s3_bucket.uploads.bucket
  key    = "database/run-seed.sh"
  source = "${path.module}/../database/scripts/run-seed.sh"
  etag   = filemd5("${path.module}/../database/scripts/run-seed.sh")
}

resource "aws_s3_object" "seed_sql" {
  count  = var.enable_migration ? 1 : 0
  bucket = aws_s3_bucket.uploads.bucket
  key    = "database/seed.sql"
  source = "${path.module}/../database/scripts/seed.sql"
  etag   = filemd5("${path.module}/../database/scripts/seed.sql")
}
