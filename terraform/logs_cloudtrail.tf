# ============================================================
# logs_cloudtrail.tf — CloudTrail 감사 로그
#   "누가 언제 AWS에서 뭘 했나" 기록
#   Management 이벤트 전체 수집 (Read + Write, Data Events 제외)
#   → S3 장기 보관 + CloudWatch → Firehose → OpenSearch Audit 카테고리
# ============================================================

resource "aws_cloudtrail" "main" {
  count = var.enable_cloudtrail ? 1 : 0
  name                          = "travel-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # Management 이벤트 전체 수집 (Read + Write, Data Events 제외)
  # basic event_selector와 혼용 불가 — advanced로 통일
  advanced_event_selector {
    name = "Management events only"
    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  depends_on = [aws_s3_bucket_policy.logs]

  tags = {
    Name    = "travel-cloudtrail"
    Project = "threetier"
  }
}

# IAM 역할은 iam.tf 에서 관리 (aws_iam_role.cloudtrail_cw)
