# ── 기존 auth_db 사용자 → Cognito 마이그레이션 Lambda ─────────────────────────
# UserMigration: 첫 로그인/비밀번호 찾기 시 bcrypt 해시를 검증하고 동일 속성으로
#                Cognito 계정을 생성 (트리거: UserMigration_Authentication / _ForgotPassword)
# PostAuthentication: 로그인 성공 직후(Cognito sub 확정 시점) auth_db.users.id 및
#                     bookings/reviews/wishlists.user_id를 새 sub으로 일괄 갱신
# 두 트리거를 Cognito User Pool에 연결하는 작업은 해당 User Pool이 Terraform으로
# 관리되지 않아 AWS CLI(aws cognito-idp update-user-pool)로 별도 수행해야 함

# 배포 zip은 terraform이 자동 생성하지 않고 수동으로 빌드해 커밋한다
# (npm install로 받은 node_modules가 gitignore 대상이라 환경마다 결과물이 달라지는 문제 방지)
# 빌드 방법: lambda/user-migration, lambda/post-authentication 폴더에서
#   npm install --omit=dev 후 폴더 내용을 zip으로 압축 → 동일 이름의 .zip으로 교체
locals {
  user_migration_zip      = "${path.module}/../lambda/user-migration.zip"
  post_authentication_zip = "${path.module}/../lambda/post-authentication.zip"
}

resource "aws_cloudwatch_log_group" "user_migration" {
  name              = "/aws/lambda/ThreeTier-User-Migration"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "post_authentication" {
  name              = "/aws/lambda/ThreeTier-Post-Authentication"
  retention_in_days = 30
}

# ── IAM 역할 (두 Lambda 공용: VPC ENI 관리 + CloudWatch Logs + Secrets 조회) ───
resource "aws_iam_role" "lambda_cognito_migration" {
  name = "ThreeTier-Lambda-CognitoMigration-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "ThreeTier-Lambda-CognitoMigration-Role" }
}

resource "aws_iam_role_policy_attachment" "lambda_cognito_migration_vpc" {
  role       = aws_iam_role.lambda_cognito_migration.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_cognito_migration_secrets" {
  role = aws_iam_role.lambda_cognito_migration.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = data.aws_secretsmanager_secret.auth.arn
    }]
  })
}

# ECS와 달리 Lambda 환경 변수는 Secrets Manager valueFrom 주입을 지원하지 않으므로
# DB_PASSWORD를 apply 시점에 조회해 환경 변수로 직접 전달한다
data "aws_secretsmanager_secret_version" "auth" {
  secret_id = data.aws_secretsmanager_secret.auth.id
}

locals {
  auth_secret = jsondecode(data.aws_secretsmanager_secret_version.auth.secret_string)
}

resource "aws_lambda_function" "user_migration" {
  function_name    = "ThreeTier-User-Migration"
  role             = aws_iam_role.lambda_cognito_migration.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = local.user_migration_zip
  source_code_hash = filebase64sha256(local.user_migration_zip)
  timeout          = 10

  vpc_config {
    subnet_ids         = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_group_ids = [aws_security_group.backend.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_rds_cluster.main.endpoint
      DB_PORT     = "3306"
      DB_USER     = "admin"
      DB_PASSWORD = local.auth_secret["DB_PASSWORD"]
    }
  }

  depends_on = [aws_cloudwatch_log_group.user_migration]
  tags       = { Name = "ThreeTier-User-Migration" }
}

resource "aws_lambda_function" "post_authentication" {
  function_name    = "ThreeTier-Post-Authentication"
  role             = aws_iam_role.lambda_cognito_migration.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = local.post_authentication_zip
  source_code_hash = filebase64sha256(local.post_authentication_zip)
  timeout          = 10

  vpc_config {
    subnet_ids         = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_group_ids = [aws_security_group.backend.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_rds_cluster.main.endpoint
      DB_PORT     = "3306"
      DB_USER     = "admin"
      DB_PASSWORD = local.auth_secret["DB_PASSWORD"]
    }
  }

  depends_on = [aws_cloudwatch_log_group.post_authentication]
  tags       = { Name = "ThreeTier-Post-Authentication" }
}

# ── Cognito가 각 Lambda를 호출할 수 있도록 권한 부여 ───────────────────────────
resource "aws_lambda_permission" "user_migration_cognito" {
  statement_id  = "AllowCognitoInvokeUserMigration"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_migration.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
}

resource "aws_lambda_permission" "post_authentication_cognito" {
  statement_id  = "AllowCognitoInvokePostAuthentication"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_authentication.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/${var.cognito_user_pool_id}"
}
