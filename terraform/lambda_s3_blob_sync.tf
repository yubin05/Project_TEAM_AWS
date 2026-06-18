# ================================================================
# 파일 경로 : terraform/lambda_s3_blob_sync.tf
# 용도      : S3 → Azure Blob Storage 이미지/첨부파일 동기화 Lambda
# 선행 조건 : iam.tf(lambda_s3_blob_sync_role) / s3.tf apply 완료
#             lambda/s3-blob-sync/index.mjs + package.json 존재
#             Secrets Manager에 threetier/azure-blob-connection-string 등록 완료
# ================================================================

# ──────────────────────────────────────────────
# 1. Lambda 배포용 zip 참조 (node_modules 포함, 수동 빌드 후 커밋)
#    배포 zip은 수동으로 빌드해 커밋한다 (lambda_image_resize.tf 참고)
#
#    빌드 시 PowerShell:
#      cd "g:\내 드라이브\Project_TEAM_AWS\lambda\s3-blob-sync"
#      $env:npm_config_platform = "linux"
#      $env:npm_config_arch = "x64"
#      npm install --omit=dev
#      (폴더 내용을 s3-blob-sync.zip으로 압축)
# ──────────────────────────────────────────────
locals {
  s3_blob_sync_zip = "${path.module}/../lambda/s3-blob-sync.zip"
}

# ──────────────────────────────────────────────
# 2. Azure Blob Connection String (AWS CLI로 미리 등록된 Secret 참조)
#    aws secretsmanager create-secret --name threetier/azure-blob-connection-string ...
# ──────────────────────────────────────────────
data "aws_secretsmanager_secret" "azure_blob_connection_string" {
  name = "threetier/azure-blob-connection-string"
}

# ──────────────────────────────────────────────
# 3. Lambda 함수 생성
# ──────────────────────────────────────────────
resource "aws_lambda_function" "s3_blob_sync" {
  function_name = "ThreeTier-S3-Blob-Sync"
  description   = "S3(hotels/thumbnails/, hotels/original/ 삭제, uploads/) → Azure Blob Storage 동기화"

  filename         = local.s3_blob_sync_zip
  source_code_hash = filebase64sha256(local.s3_blob_sync_zip)

  runtime = "nodejs20.x"
  handler = "index.handler"
  role    = aws_iam_role.lambda_s3_blob_sync_role.arn

  # S3 다운로드 + Azure Blob 업로드(인터넷 경유) 시간 고려
  timeout     = 60
  memory_size = 256

  environment {
    variables = {
      AZURE_BLOB_CONNECTION_STRING_SECRET_ARN = data.aws_secretsmanager_secret.azure_blob_connection_string.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_s3_blob_sync]

  tags = {
    Name      = "ThreeTier-S3-Blob-Sync"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 4. S3가 Lambda를 호출할 수 있도록 권한 부여
# ──────────────────────────────────────────────
resource "aws_lambda_permission" "allow_s3_invoke_blob_sync" {
  statement_id  = "AllowS3InvokeBlobSync"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_blob_sync.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

# ──────────────────────────────────────────────
# 5. Outputs
# ──────────────────────────────────────────────
output "s3_blob_sync_function_name" {
  description = "s3-blob-sync Lambda 함수 이름"
  value       = aws_lambda_function.s3_blob_sync.function_name
}

output "s3_blob_sync_function_arn" {
  description = "s3-blob-sync Lambda 함수 ARN"
  value       = aws_lambda_function.s3_blob_sync.arn
}
