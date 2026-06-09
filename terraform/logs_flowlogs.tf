# ============================================================
# 내용: VPC 네트워크 트래픽 로그
#   ① S3 전송 — 전체 트래픽(ALL) 장기 보관
#   ② CloudWatch 전송 — 차단 트래픽(REJECT)만 실시간 모니터링
#     └─ Kinesis Firehose → OpenSearch Infrastructure 카테고리
# ============================================================

# ① S3 — 전체 트래픽 장기 보관 (기존 유지)
resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${aws_s3_bucket.logs.arn}/vpc-flow-logs/"

  tags = { Name = "ThreeTier-VPC-FlowLogs-S3" }

  depends_on = [aws_s3_bucket_policy.logs]
}

# ② CloudWatch — REJECT 트래픽만 (OpenSearch 실시간 모니터링용)
# 로그 그룹: logs_loggroups.tf / IAM 역할: iam.tf

resource "aws_flow_log" "main_cw" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "REJECT"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs_cw.arn

  tags = { Name = "ThreeTier-VPC-FlowLogs-CW" }
}
