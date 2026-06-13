# ── Pre Token Generation Lambda ──────────────────────────────────────────────
# Cognito Access Token은 커스텀 속성(custom:*)을 기본적으로 포함하지 않아
# 백엔드 미들웨어가 읽는 payload['custom:role']이 항상 비어 권한 검사가 실패함.
# 토큰 발급 시점에 사용자의 custom:role 값을 Access Token 클레임으로 복사해 넣는다.
# (DB 접근이 없어 VPC 배치 불필요. 트리거 연결은 User Pool이 Terraform 미관리라
#  AWS CLI(aws cognito-idp update-user-pool --lambda-config ...)로 별도 수행)

# 배포 zip은 수동으로 빌드해 커밋한다 (lambda_user_migration.tf 참고)
locals {
  pre_token_generation_zip = "${path.module}/../lambda/pre-token-generation.zip"
}

resource "aws_iam_role" "lambda_pre_token_generation" {
  name = "ThreeTier-Lambda-PreTokenGeneration-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-Lambda-PreTokenGeneration-Role" }
}

resource "aws_iam_role_policy_attachment" "lambda_pre_token_generation_logs" {
  role       = aws_iam_role.lambda_pre_token_generation.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "pre_token_generation" {
  function_name    = "ThreeTier-Pre-Token-Generation"
  role             = aws_iam_role.lambda_pre_token_generation.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = local.pre_token_generation_zip
  source_code_hash = filebase64sha256(local.pre_token_generation_zip)
  timeout          = 5

  depends_on = [aws_cloudwatch_log_group.pre_token_generation]
  tags       = { Name = "ThreeTier-Pre-Token-Generation" }
}

resource "aws_lambda_permission" "pre_token_generation_cognito" {
  statement_id  = "AllowCognitoInvokePreTokenGeneration"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token_generation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
}
