# ============================================================
# logs_alb.tf — ALB 액세스 로그 파이프라인
#
# 흐름:
#   ALB → S3 (alb-access-logs/) → S3 이벤트 → Lambda
#     → Kinesis Firehose → OpenSearch (category: Access)
#
# ALB → S3 설정: alb.tf 에서 관리
# S3 버킷 정책 (ALB 쓰기 허용): logs_s3.tf 에서 관리
# ============================================================


# ── 1. IAM Role: ALB 로그 처리 Lambda ────────────────────────

resource "aws_iam_role" "lambda_alb_log_processor" {
  name = "ThreeTier-Lambda-ALBLogProcessor-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-Lambda-ALBLogProcessor-Role", Project = "threetier" }
}

resource "aws_iam_role_policy_attachment" "lambda_alb_basic" {
  role       = aws_iam_role.lambda_alb_log_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_alb_log_processor" {
  name = "ThreeTier-Lambda-ALBLogProcessor-Policy"
  role = aws_iam_role.lambda_alb_log_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.logs.arn}/alb-access-logs/*"
      },
      {
        Effect   = "Allow"
        Action   = ["firehose:PutRecordBatch"]
        Resource = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
      }
    ]
  })
}


# ── 2. Lambda 함수: ALB 로그 파싱 → Firehose ─────────────────

data "archive_file" "alb_log_processor" {
  type        = "zip"
  output_path = "${path.module}/lambda_alb_processor.zip"

  source {
    filename = "index.py"
    content  = <<-PYTHON
import boto3, gzip, json, re, os

FIREHOSE_STREAM = os.environ['FIREHOSE_STREAM_NAME']
firehose  = boto3.client('firehose')
s3_client = boto3.client('s3')

# 공백 구분 + 따옴표 필드 파싱 (ALB 로그 포맷)
ALB_RE = re.compile(r'"[^"]*"|[^ ]+')

def parse_line(line):
    fields = ALB_RE.findall(line)
    if len(fields) < 13:
        return None
    status = fields[8].strip('"')
    level  = 'ERROR' if status.startswith('5') else 'WARN' if status.startswith('4') else 'INFO'
    try:
        resp_ms = int(float(fields[7]) * 1000)
    except (ValueError, IndexError):
        resp_ms = -1
    return {
        'timestamp':       fields[1].strip('"'),
        'category':        'Access',
        'service':         'alb',
        'level':           level,
        'elb_status_code': status,
        'client_ip':       fields[3].split(':')[0],
        'request':         fields[12].strip('"'),
        'user_agent':      fields[13].strip('"') if len(fields) > 13 else '-',
        'response_time_ms': resp_ms,
    }

def lambda_handler(event, context):
    records = []

    for s3_record in event['Records']:
        bucket = s3_record['s3']['bucket']['name']
        key    = s3_record['s3']['object']['key']
        obj    = s3_client.get_object(Bucket=bucket, Key=key)
        body   = gzip.decompress(obj['Body'].read()).decode('utf-8')

        for line in body.splitlines():
            if not line or line.startswith('#'):
                continue
            parsed = parse_line(line)
            if parsed:
                records.append({'Data': (json.dumps(parsed) + '\n').encode()})

            # Firehose PutRecordBatch 최대 500건
            if len(records) >= 500:
                firehose.put_record_batch(DeliveryStreamName=FIREHOSE_STREAM, Records=records)
                records = []

    if records:
        firehose.put_record_batch(DeliveryStreamName=FIREHOSE_STREAM, Records=records)
PYTHON
  }
}

resource "aws_lambda_function" "alb_log_processor" {
  function_name    = "threetier-alb-log-processor"
  description      = "ALB 액세스 로그 S3 → Firehose → OpenSearch"
  role             = aws_iam_role.lambda_alb_log_processor.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.alb_log_processor.output_path
  source_code_hash = data.archive_file.alb_log_processor.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      FIREHOSE_STREAM_NAME = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.name
    }
  }

  tags = { Name = "threetier-alb-log-processor", Project = "threetier" }
}


# ── 3. S3 → Lambda 호출 권한 ─────────────────────────────────

resource "aws_lambda_permission" "allow_s3_alb_logs" {
  statement_id  = "AllowS3InvokeALBLogProcessor"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alb_log_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.logs.arn
}


# ── 4. S3 이벤트 알림 → Lambda 트리거 ────────────────────────

resource "aws_s3_bucket_notification" "alb_logs_to_lambda" {
  bucket     = aws_s3_bucket.logs.id
  depends_on = [aws_lambda_permission.allow_s3_alb_logs]

  lambda_function {
    lambda_function_arn = aws_lambda_function.alb_log_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "alb-access-logs/"
  }
}


# ── 5. CloudWatch 로그 그룹 ───────────────────────────────────

resource "aws_cloudwatch_log_group" "alb_log_processor" {
  name              = "/aws/lambda/threetier-alb-log-processor"
  retention_in_days = 14
  tags              = { Name = "alb-log-processor-log-group", Project = "threetier" }
}
