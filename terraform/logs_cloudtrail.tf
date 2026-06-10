# ============================================================
# logs_cloudtrail.tf — CloudTrail 감사 로그
#   "누가 언제 AWS에서 뭘 했나" 기록
#   WriteOnly 이벤트만 수집 (콘솔 변경, 리소스 생성/삭제 등)
#   → S3 장기 보관 + CloudWatch → Firehose → OpenSearch Audit 카테고리
# ============================================================

resource "aws_cloudtrail" "main" {
  name                          = "travel-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.logs.id
  s3_key_prefix                 = "cloudtrail"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # WriteOnly: 콘솔/API로 뭔가를 변경한 이벤트만 수집
  # Read 이벤트(목록 조회 등)는 너무 많아서 제외
  event_selector {
    read_write_type           = "WriteOnly"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.logs]

  tags = {
    Name    = "travel-cloudtrail"
    Project = "threetier"
  }
}

# IAM 역할은 iam.tf 에서 관리 (aws_iam_role.cloudtrail_cw)
