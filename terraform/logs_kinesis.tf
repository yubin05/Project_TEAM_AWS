# ============================================================
# logs_kinesis.tf — Kinesis Data Firehose 실시간 파이프라인
#
# 흐름:
#   CloudWatch Log Groups
#     → (subscription filter) → Kinesis Data Firehose
#     → (Lambda 압축해제·변환) → S3 백업 + OpenSearch 인덱싱
#
# 구독 대상 로그 그룹:
#   - /aws/apigateway/threetier-http-api
#   - /aws/lambda/booking-notification
#   - /aws/lambda/image-resize
#   - /aws/lambda/cognito-post-confirm
#   - aws-waf-logs-threetier
# ============================================================


# ── 1. Lambda: CloudWatch Logs 데이터 변환 ──────────────────
# CloudWatch Logs → Firehose 데이터는 base64+gzip 압축 형태임
# 이 Lambda가 압축 해제 후 개별 JSON 이벤트로 변환해 OpenSearch가 인덱싱할 수 있게 함

data "archive_file" "cw_transform" {
  type        = "zip"
  output_path = "${path.module}/../lambda/lambda_cw_transform.zip"

  source {
    filename = "index.py"
    content  = <<-PYTHON
import base64, gzip, json, re

# logGroup → 카테고리 매핑
CATEGORY_MAP = [
    ('/aws/cloudtrail/',         'Audit'),
    ('/aws/dms/',                'Migration'),
    ('/threetier/vpc-flow-logs', 'Infrastructure'),
    ('/aws/rds/',                'Application'),
    ('/aws/apigateway/',         'Access'),
    ('/aws/lambda/',             'Application'),
    ('/ecs/',                    'Application'),
    ('aws-waf-logs',             'Application'),
]

# 로그 레벨 키워드 추출 (대소문자 무관)
LEVEL_RE = re.compile(r'\b(FATAL|CRITICAL|ERROR|WARN(?:ING)?|INFO|DEBUG|TRACE)\b', re.IGNORECASE)

def get_category(log_group):
    for prefix, cat in CATEGORY_MAP:
        if prefix in log_group:
            return cat
    return 'Application'

def get_service(log_group):
    # /ecs/booking-service    → booking-service
    # /aws/lambda/image-resize → image-resize
    # /aws/apigateway/threetier-http-api → threetier-http-api
    return log_group.rstrip('/').split('/')[-1]

def get_level(message):
    m = LEVEL_RE.search(message)
    if not m:
        return 'INFO'
    lvl = m.group(1).upper()
    return 'WARN' if lvl == 'WARNING' else lvl

def lambda_handler(event, context):
    output = []
    for record in event['records']:
        raw = base64.b64decode(record['data'])

        # ALB Lambda puts pre-formatted JSON directly to Firehose (not gzip)
        try:
            log_data = json.loads(gzip.decompress(raw))
        except (gzip.BadGzipFile, OSError):
            output.append({'recordId': record['recordId'], 'result': 'Ok', 'data': record['data']})
            continue

        if log_data.get('messageType') == 'CONTROL_MESSAGE':
            output.append({'recordId': record['recordId'], 'result': 'Dropped', 'data': record['data']})
            continue

        category = get_category(log_data['logGroup'])
        service  = get_service(log_data['logGroup'])
        lines = []
        for ev in log_data.get('logEvents', []):
            message = ev['message']
            lines.append(json.dumps({
                'timestamp': ev['timestamp'],
                'logGroup':  log_data['logGroup'],
                'logStream': log_data['logStream'],
                'category':  category,
                'service':   service,
                'level':     get_level(message),
                'message':   message
            }))

        if lines:
            encoded = base64.b64encode(('\n'.join(lines) + '\n').encode()).decode()
            output.append({'recordId': record['recordId'], 'result': 'Ok', 'data': encoded})
        else:
            output.append({'recordId': record['recordId'], 'result': 'Dropped', 'data': record['data']})

    return {'records': output}
PYTHON
  }
}

resource "aws_lambda_function" "cw_transform" {
  filename         = data.archive_file.cw_transform.output_path
  source_code_hash = data.archive_file.cw_transform.output_base64sha256
  function_name    = "threetier-cw-log-transform"
  role             = aws_iam_role.lambda_cw_transform.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60

  tags = { Name = "threetier-cw-log-transform", Project = "threetier" }
}


# ── 2. Kinesis Data Firehose 스트림 ─────────────────────────

resource "aws_kinesis_firehose_delivery_stream" "logs_to_opensearch" {
  name        = "threetier-logs-to-opensearch"
  destination = "opensearch"

  opensearch_configuration {
    domain_arn            = aws_opensearch_domain.logs.arn
    role_arn              = aws_iam_role.firehose.arn
    index_name            = "cwlogs"
    index_rotation_period = "OneDay"   # 날짜별 인덱스: cwlogs-2025-01-01
    buffering_interval    = 60         # 최대 60초 버퍼링 후 전송
    buffering_size        = 5          # 5MB 쌓이면 즉시 전송

    # 모든 레코드를 S3에도 동시 백업 (장기 보관 + Athena 분석용)
    s3_backup_mode = "AllDocuments"

    s3_configuration {
      role_arn           = aws_iam_role.firehose.arn
      bucket_arn         = aws_s3_bucket.logs.arn
      prefix             = "cloudwatch-export/"
      buffering_interval = 300
      buffering_size     = 5
      compression_format = "GZIP"
    }

    # Lambda 변환: base64+gzip 압축 → 개별 JSON 이벤트
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"
        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = "${aws_lambda_function.cw_transform.arn}:$LATEST"
        }
      }
    }

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/threetier-logs-to-opensearch"
      log_stream_name = "DestinationDelivery"
    }

    # Firehose가 VPC 내 OpenSearch에 접근하기 위한 ENI 설정
    vpc_config {
      subnet_ids         = [aws_subnet.private_backend.id]
      security_group_ids = [aws_security_group.firehose_to_opensearch.id]
      role_arn           = aws_iam_role.firehose.arn
    }
  }

  tags = { Name = "threetier-logs-to-opensearch", Project = "threetier" }
}


# ── 5. CloudWatch Logs 구독 필터 ─────────────────────────────
# 각 로그 그룹의 모든 이벤트를 Firehose로 실시간 전달
# filter_pattern = "" → 필터 없이 전체 로그 전송

resource "aws_cloudwatch_log_subscription_filter" "apigateway_to_firehose" {
  name            = "apigateway-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.api_gateway.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "lambda_booking_to_firehose" {
  name            = "lambda-booking-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.lambda_booking_notification.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "lambda_image_to_firehose" {
  name            = "lambda-image-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.lambda_image_resize.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "lambda_cognito_to_firehose" {
  name            = "lambda-cognito-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.lambda_cognito_post_confirm.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "waf_to_firehose" {
  name            = "waf-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.waf.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "vpc_flowlogs_to_firehose" {
  name            = "vpc-flowlogs-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.vpc_flow_logs.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "cloudtrail_to_firehose" {
  name            = "cloudtrail-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.cloudtrail.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

# ── ECS 서비스 로그 (5개) ────────────────────────────────────
# auth / hotel / booking / review / support → Application 카테고리

resource "aws_cloudwatch_log_subscription_filter" "ecs_auth_to_firehose" {
  name            = "ecs-auth-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.auth.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_hotel_to_firehose" {
  name            = "ecs-hotel-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.hotel.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_booking_to_firehose" {
  name            = "ecs-booking-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.booking.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_review_to_firehose" {
  name            = "ecs-review-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.review.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_support_to_firehose" {
  name            = "ecs-support-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.support.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

# ── DMS 태스크 로그 ──────────────────────────────────────────
resource "aws_cloudwatch_log_subscription_filter" "dms_task_to_firehose" {
  name            = "dms-task-to-firehose"
  log_group_name  = aws_cloudwatch_log_group.dms_task.name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

# ── RDS Aurora 로그 (error / general / slowquery) ────────────
resource "aws_cloudwatch_log_subscription_filter" "rds_error_to_firehose" {
  name            = "rds-error-to-firehose"
  log_group_name  = "/aws/rds/cluster/threetier-aurora-cluster/error"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose]
}

resource "aws_cloudwatch_log_subscription_filter" "rds_general_to_firehose" {
  name            = "rds-general-to-firehose"
  log_group_name  = "/aws/rds/cluster/threetier-aurora-cluster/general"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose, aws_cloudwatch_log_group.rds_general]
}

resource "aws_cloudwatch_log_subscription_filter" "rds_slowquery_to_firehose" {
  name            = "rds-slowquery-to-firehose"
  log_group_name  = "/aws/rds/cluster/threetier-aurora-cluster/slowquery"
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
  depends_on      = [aws_iam_role_policy.cloudwatch_to_firehose, aws_cloudwatch_log_group.rds_slowquery]
}
