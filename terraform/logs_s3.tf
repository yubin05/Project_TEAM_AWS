# ============================================================
# 내용: 로그 저장용 S3 버킷 + 버킷 정책
#   - VPC Flow Logs / CloudTrail / ALB 액세스 로그 / CloudWatch Export 전용
#   - 퍼블릭 차단 + SSE-S3 암호화
#   - 30일 후 Glacier 자동 이동, 365일 후 삭제
# ============================================================

resource "aws_s3_bucket" "logs" {
  bucket        = "threetier-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "ThreeTier-Logs" }
}

# 퍼블릭 액세스 전체 차단
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 수명 주기 — 로그: 30일 후 Glacier, 365일 후 삭제 / Athena 결과: 7일 후 삭제
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-lifecycle"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  # Athena 쿼리 결과는 임시 파일이므로 7일 후 삭제 (Glacier 이전 없음)
  rule {
    id     = "athena-results-cleanup"
    status = "Enabled"
    filter {
      prefix = "athena-results/"
    }
    expiration {
      days = 7
    }
  }
}

# 버킷 정책 — 각 서비스별 최소 권한만 허용
resource "aws_s3_bucket_policy" "logs" {
  bucket     = aws_s3_bucket.logs.id
  depends_on = [aws_s3_bucket_public_access_block.logs]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # VPC Flow Logs 전송 허용
      {
        Sid       = "AllowVPCFlowLogs"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/vpc-flow-logs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "AllowVPCFlowLogsAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      # CloudTrail 전송 허용
      {
        Sid       = "AllowCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/cloudtrail/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "AllowCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.logs.arn
      },
      # ALB 액세스 로그 전송 허용 (서울 리전 ELB 계정 ID: 600734575887)
      {
        Sid       = "AllowALBAccessLogs"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::600734575887:root" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/alb-access-logs/*"
      },
      # CloudWatch Logs Export 허용
      {
        Sid       = "AllowCloudWatchLogsExport"
        Effect    = "Allow"
        Principal = { Service = "logs.ap-northeast-2.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/cloudwatch-export/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}
