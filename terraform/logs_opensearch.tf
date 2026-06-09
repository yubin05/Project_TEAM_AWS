# ============================================================
# logs_opensearch.tf — OpenSearch 도메인
#   CloudWatch 로그 실시간 검색·시각화 엔진
#   Kinesis Firehose(logs_kinesis.tf)로부터 로그 수신
#   접속: https://<endpoint>/_dashboards (ID/PW 로그인)
# ============================================================

resource "aws_opensearch_domain" "logs" {
  domain_name    = "threetier-logs"
  engine_version = "OpenSearch_2.13"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 1
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = 20
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # 사용자 이름/비밀번호로 Dashboards 접근 (Fine-Grained Access Control)
  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name     = var.opensearch_master_user
      master_user_password = var.opensearch_master_password
    }
  }

  # FGAC 활성화 시 도메인 정책은 전체 허용으로 설정 (실제 보안은 FGAC가 담당)
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = "*" }
        Action    = "es:*"
        Resource  = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/threetier-logs/*"
      }
    ]
  })

  tags = {
    Name    = "threetier-logs"
    Project = "threetier"
  }
}

# ── 배포 후 Firehose 역할 연결 필요 (수동 1회 작업) ──────────
# OpenSearch Dashboards → Security → Roles → all_access
# → Backend roles 탭 → ThreeTier-Firehose-Role ARN 추가
# 이 작업이 있어야 Kinesis Firehose가 OpenSearch에 로그를 쓸 수 있음

output "opensearch_endpoint" {
  value       = aws_opensearch_domain.logs.endpoint
  description = "OpenSearch 도메인 엔드포인트"
}

output "opensearch_dashboard_url" {
  value       = "https://${aws_opensearch_domain.logs.endpoint}/_dashboards"
  description = "OpenSearch Dashboards URL — 브라우저에서 열기"
}
