# ============================================================
# 내용: VPC 네트워크 트래픽 전체 → S3 전송
#   - 허용/차단 트래픽 모두 기록 (ALL)
#   - logs_s3.tf의 S3 버킷에 저장
# ============================================================

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${aws_s3_bucket.logs.arn}/vpc-flow-logs/"

  tags = { Name = "ThreeTier-VPC-FlowLogs" }

  depends_on = [aws_s3_bucket_policy.logs]
}
