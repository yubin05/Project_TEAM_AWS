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
    volume_size = 50
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

  # VPC 배포: 네트워크 격리가 기본 보안 레이어, FGAC가 인증 레이어
  # IP 화이트리스트 불필요 — VPC SG가 Firehose/SSM tunnel 만 허용
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/threetier-logs/*"
    }]
  })

  # OpenSearch를 VPC private subnet에 배포
  # 퍼블릭 엔드포인트 없음 — SSM 포트 포워딩으로만 접근
  vpc_options {
    subnet_ids         = [aws_subnet.private_backend.id]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  tags = {
    Name    = "threetier-logs"
    Project = "threetier"
  }
}

# ── 배포 후 1회 설정 스크립트 자동 생성 ──────────────────────
# terraform apply 완료 후 opensearch_setup.sh 파일이 terraform/ 폴더에 생성됨
# SSM 터널 활성화 상태에서 bash terraform/opensearch_setup.sh 실행
#
# 스크립트가 처리하는 두 가지 작업:
#   1. Firehose IAM 역할 → OpenSearch all_access 백엔드 역할 매핑
#      (이 작업 없으면 Firehose가 OpenSearch에 로그 쓰기 거부됨)
#   2. cwlogs-* 인덱스 7일 후 자동 삭제 ISM 정책 등록
#      (이 작업 없으면 인덱스가 무한 누적되어 50GB 스토리지 고갈)

resource "local_file" "opensearch_setup_script" {
  filename        = "${path.module}/opensearch_setup.sh"
  file_permission = "0755"

  content = <<-SCRIPT
#!/bin/bash
# OpenSearch 배포 후 1회 설정 스크립트
# 사전 조건: SSM 포트 포워딩 터널이 활성화된 상태에서 실행
#
# 터널 실행 명령:
#   aws ssm start-session \
#     --target $(terraform -chdir=$(dirname $0) output -raw ssm_tunnel_instance_id) \
#     --document-name AWS-StartPortForwardingSessionToRemoteHost \
#     --parameters '{"host":["${aws_opensearch_domain.logs.endpoint}"],"portNumber":["443"],"localPortNumber":["9200"]}'
#
# 터널 실행 후 이 스크립트를 실행하세요.

set -e

OS_URL="https://localhost:9200"
USER="${var.opensearch_master_user}"
PASS="${var.opensearch_master_password}"
FIREHOSE_ARN="${aws_iam_role.firehose.arn}"

echo "OpenSearch 연결 확인 중..."
if ! curl -sk -u "$USER:$PASS" "$OS_URL" > /dev/null 2>&1; then
  echo "ERROR: OpenSearch 에 연결할 수 없습니다. SSM 터널이 실행 중인지 확인하세요."
  exit 1
fi
echo "연결 확인 완료."
echo ""

echo "1/2. Firehose IAM 역할 → OpenSearch all_access 매핑..."
RESULT=$(curl -sk -u "$USER:$PASS" \
  -X PUT "$OS_URL/_plugins/_security/api/rolesmapping/all_access" \
  -H "Content-Type: application/json" \
  -d "{\"backend_roles\":[\"$FIREHOSE_ARN\"]}")
echo "$RESULT"
echo ""

echo "2/2. ISM 정책 등록 (cwlogs-* 인덱스 7일 후 자동 삭제)..."
RESULT=$(curl -sk -u "$USER:$PASS" \
  -X PUT "$OS_URL/_plugins/_ism/policies/cwlogs-cleanup" \
  -H "Content-Type: application/json" \
  -d '{
    "policy": {
      "description": "cwlogs 7일 보관 후 자동 삭제",
      "default_state": "hot",
      "states": [
        {
          "name": "hot",
          "actions": [],
          "transitions": [{"state_name":"delete","conditions":{"min_index_age":"7d"}}]
        },
        {
          "name": "delete",
          "actions": [{"delete":{}}],
          "transitions": []
        }
      ],
      "ism_template": [{"index_patterns":["cwlogs-*"],"priority":100}]
    }
  }')
echo "$RESULT"
echo ""
echo "완료! OpenSearch Dashboards: https://localhost:9200/_dashboards"
SCRIPT
}

output "opensearch_vpc_endpoint" {
  value       = aws_opensearch_domain.logs.endpoint
  description = "OpenSearch VPC 엔드포인트 호스트명 (SSM 포트 포워딩 target host)"
}

output "opensearch_ssm_tunnel_cmd" {
  value       = "aws ssm start-session --target $(terraform output -raw ssm_tunnel_instance_id) --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"${aws_opensearch_domain.logs.endpoint}\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"9200\"]}'"
  description = "로컬에서 실행할 SSM 포트 포워딩 명령 → 브라우저에서 https://localhost:9200/_dashboards 접속"
}
