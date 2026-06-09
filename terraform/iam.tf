# ── SSM ──────────────────────────────────────────────────────────────────────
# EC2 콘솔 → 연결 → Session Manager 탭에서 키 없이 접속 가능
resource "aws_iam_role" "ssm" {
  name = "ThreeTier-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-SSM-Role" }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "ThreeTier-SSM-InstanceProfile"
  role = aws_iam_role.ssm.name
}

resource "aws_iam_role_policy" "ssm_s3_read" {
  role = aws_iam_role.ssm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.uploads.arn}/database/*"
    }]
  })
}

# ── ECS ───────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ecs_task_execution" {
  name = "ThreeTier-ECS-TaskExecution-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-ECS-TaskExecution-Role" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_s3_uploads" {
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "ThreeTier-ECS-Task-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-ECS-Task-Role" }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  role = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:Travel-*"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
      Resource = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_sqs" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_role_policy" "ecs_task_cognito" {
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:AdminConfirmSignUp",
        "cognito-idp:AdminCreateUser",
        "cognito-idp:AdminSetUserPassword"
      ]
      Resource = "arn:aws:cognito-idp:${var.aws_region}:*:userpool/*"
    }]
  })
}

# resource "aws_iam_role_policy_attachment" "ecs_task_dynamodb" {
#   role       = aws_iam_role.ecs_task.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
# }
#
# resource "aws_iam_role_policy_attachment" "ecs_task_bedrock" {
#   role       = aws_iam_role.ecs_task.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
# }

resource "aws_iam_role_policy_attachment" "ecs_task_ses" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

# ── CodeDeploy ────────────────────────────────────────────────────────────────
resource "aws_iam_role" "codedeploy" {
  name = "ThreeTier-CodeDeploy-ECS-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codedeploy.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# ── CodePipeline ──────────────────────────────────────────────────────────────
resource "aws_iam_role" "codepipeline" {
  name = "ThreeTier-CodePipeline-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  role = aws_iam_role.codepipeline.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}", "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["codedeploy:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = "*"
      }
    ]
  })
}

# ── Logging — Lambda CW Transform ────────────────────────────────────────────
resource "aws_iam_role" "lambda_cw_transform" {
  name = "ThreeTier-Lambda-CWTransform-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-Lambda-CWTransform-Role", Project = "threetier" }
}

resource "aws_iam_role_policy_attachment" "lambda_cw_transform_basic" {
  role       = aws_iam_role.lambda_cw_transform.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── Logging — Kinesis Firehose ────────────────────────────────────────────────
resource "aws_iam_role" "firehose" {
  name = "ThreeTier-Firehose-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-Firehose-Role", Project = "threetier" }
}

resource "aws_iam_role_policy" "firehose" {
  name = "ThreeTier-Firehose-Policy"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:AbortMultipartUpload", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["es:DescribeDomain", "es:DescribeElasticsearchDomain", "es:DescribeElasticsearchDomains", "es:DescribeElasticsearchDomainConfig", "es:ESHttpPost", "es:ESHttpPut", "es:ESHttpGet"]
        Resource = [aws_opensearch_domain.logs.arn, "${aws_opensearch_domain.logs.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.cw_transform.arn
      },
      {
        Effect = "Allow"
        Action = ["logs:PutLogEvents", "logs:CreateLogGroup", "logs:CreateLogStream"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# ── Logging — CloudWatch Logs → Firehose ──────────────────────────────────────
resource "aws_iam_role" "cloudwatch_to_firehose" {
  name = "ThreeTier-CWLogs-To-Firehose-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-CWLogs-To-Firehose-Role", Project = "threetier" }
}

resource "aws_iam_role_policy" "cloudwatch_to_firehose" {
  name = "ThreeTier-CWLogs-To-Firehose-Policy"
  role = aws_iam_role.cloudwatch_to_firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "firehose:PutRecord"
      Resource = aws_kinesis_firehose_delivery_stream.logs_to_opensearch.arn
    }]
  })
}

# ── Logging — VPC Flow Logs → CloudWatch ──────────────────────────────────────
resource "aws_iam_role" "vpc_flow_logs_cw" {
  name = "ThreeTier-VPCFlowLogs-CW-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-VPCFlowLogs-CW-Role", Project = "threetier" }
}

resource "aws_iam_role_policy" "vpc_flow_logs_cw" {
  name = "ThreeTier-VPCFlowLogs-CW-Policy"
  role = aws_iam_role.vpc_flow_logs_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

# ── Logging — CloudTrail → CloudWatch ────────────────────────────────────────
resource "aws_iam_role" "cloudtrail_cw" {
  name = "ThreeTier-CloudTrail-CW-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-CloudTrail-CW-Role", Project = "threetier" }
}

resource "aws_iam_role_policy" "cloudtrail_cw" {
  name = "ThreeTier-CloudTrail-CW-Policy"
  role = aws_iam_role.cloudtrail_cw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
    }]
  })
}

# ── Logging — Slack Notifier Lambda ──────────────────────────────────────────
resource "aws_iam_role" "slack_notifier_lambda" {
  name = "SlackNotifierLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "SlackNotifierLambdaRole" }
}

resource "aws_iam_role_policy" "slack_notifier_lambda_logs" {
  name = "SlackNotifierLambdaLogsPolicy"
  role = aws_iam_role.slack_notifier_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/slack-notifier:*"
    }]
  })
}

# ── CodeBuild ─────────────────────────────────────────────────────────────────
resource "aws_iam_role" "codebuild" {
  name = "ThreeTier-CodeBuild-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:Travel-*"
      }
    ]
  })
}

# ── Lambda: SQS → Lambda → SES (예약 알림 이메일) ────────────────────────────
# 기능: booking-service가 SQS에 예약 정보 전송 → Lambda가 소비 → SES로 확인 메일 발송
# 관련 파일: lambda.tf, sqs.tf, ses.tf

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_notification_role" {
  name               = "ThreeTier-Lambda-Notification-Role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags = {
    Name      = "ThreeTier-Lambda-Notification-Role"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "lambda_notification_policy" {
  # ① CloudWatch Logs — 실행 로그 기록
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/ThreeTier-Booking-Notification:*"
    ]
  }

  # ② SQS 본 큐 — 메시지 수신 & 삭제
  statement {
    sid    = "AllowSQSConsume"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.booking_notification.arn]
  }

  # ③ SQS DLQ — 속성 조회 (모니터링용, 쓰기 권한 없음)
  statement {
    sid    = "AllowDLQRead"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.booking_dlq.arn]
  }

  # ④ SES — 발신자 Identity에서 이메일 발송
  #    SES는 ses:SendEmail 권한 검사를 발신자뿐 아니라, 같은 계정 내에서
  #    검증된 "수신자" Identity의 ARN에도 적용한다. 테스트 단계에서는
  #    수신 테스트용 이메일이 계속 추가/교체되므로 계정 내 모든 Identity로 범위를 둔다.
  statement {
    sid    = "AllowSESSend"
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail"
    ]
    resources = ["arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/*"]
  }
}

resource "aws_iam_policy" "lambda_notification_policy" {
  name        = "ThreeTier-Lambda-Notification-Policy"
  description = "ThreeTier booking-notification Lambda 최소 권한"
  policy      = data.aws_iam_policy_document.lambda_notification_policy.json
  tags = {
    Name      = "ThreeTier-Lambda-Notification-Policy"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_notification" {
  role       = aws_iam_role.lambda_notification_role.name
  policy_arn = aws_iam_policy.lambda_notification_policy.arn
}

output "lambda_notification_role_arn" {
  description = "Lambda 함수 생성 시 role에 지정할 ARN (lambda.tf 참조)"
  value       = aws_iam_role.lambda_notification_role.arn
}

# SQS Queue Policy: Lambda Role만 메시지 소비 허용 (이중 레이어 접근 제어)
resource "aws_sqs_queue_policy" "booking_notification" {
  queue_url = aws_sqs_queue.booking_notification.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Secrets Manager 구현 및 ECS Task Role 활성화 후 아래 블록 주석 해제
      {
        Sid    = "AllowECSBookingServiceSend"
        Effect = "Allow"
        Principal = { AWS = aws_iam_role.ecs_task.arn }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.booking_notification.arn
      },
      {
        Sid    = "AllowLambdaConsume"
        Effect = "Allow"
        Principal = { AWS = aws_iam_role.lambda_notification_role.arn }
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.booking_notification.arn
      }
    ]
  })
}

# ── Lambda: S3 이미지 업로드 → 썸네일 리사이즈 ──────────────────────────────
# 기능: S3 hotels/original/ 에 이미지 업로드 시 Lambda 자동 실행 → Sharp로 리사이즈 → thumbnails/ 저장
# 관련 파일: lambda_image_resize.tf, s3.tf

data "aws_iam_policy_document" "lambda_image_resize_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_image_resize_role" {
  name               = "ThreeTier-Lambda-ImageResize-Role"
  assume_role_policy = data.aws_iam_policy_document.lambda_image_resize_assume.json
  tags = {
    Name      = "ThreeTier-Lambda-ImageResize-Role"
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "lambda_image_resize_policy" {
  # ① CloudWatch Logs — 실행 로그 기록
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/ThreeTier-Image-Resize:*"
    ]
  }

  # ② S3 원본 이미지 읽기 (hotels/original/ 경로만 허용)
  statement {
    sid     = "AllowS3GetOriginal"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.uploads.arn}/hotels/original/*"
    ]
  }

  # ③ S3 썸네일 쓰기 (hotels/thumbnails/ 경로만 허용)
  statement {
    sid     = "AllowS3PutThumbnail"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.uploads.arn}/hotels/thumbnails/*"
    ]
  }
}

resource "aws_iam_policy" "lambda_image_resize_policy" {
  name        = "ThreeTier-Lambda-ImageResize-Policy"
  description = "image-resize Lambda 최소 권한 (S3 원본 읽기 + 썸네일 쓰기 + CloudWatch)"
  policy      = data.aws_iam_policy_document.lambda_image_resize_policy.json
  tags = {
    Name      = "ThreeTier-Lambda-ImageResize-Policy"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_image_resize" {
  role       = aws_iam_role.lambda_image_resize_role.name
  policy_arn = aws_iam_policy.lambda_image_resize_policy.arn
}
