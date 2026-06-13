# ================================================================
# 파일 경로 : terraform/lambda_image_resize.tf
# 용도      : image-resize Lambda 생성 + S3 이벤트 트리거 연결
# 선행 조건 : iam_lambda_image_resize.tf / s3.tf apply 완료
#             lambda/image-resize/index.mjs + package.json 존재
# ================================================================

# ──────────────────────────────────────────────
# 1. Lambda 배포용 zip 참조 (node_modules 포함, 수동 빌드 후 커밋)
#    배포 zip은 수동으로 빌드해 커밋한다 (lambda_user_migration.tf 참고)
#
#    빌드 시 PowerShell:
#      cd "g:\내 드라이브\Project_TEAM_AWS\lambda\image-resize"
#      $env:npm_config_platform = "linux"
#      $env:npm_config_arch = "x64"
#      npm install --omit=dev
#      (폴더 내용을 image-resize.zip으로 압축)
# ──────────────────────────────────────────────
locals {
  image_resize_zip = "${path.module}/../lambda/image-resize.zip"
}

# ──────────────────────────────────────────────
# 4. Lambda 함수 생성
# ──────────────────────────────────────────────
resource "aws_lambda_function" "image_resize" {
  function_name = "ThreeTier-Image-Resize"
  description   = "S3 호텔 이미지 업로드(hotels/original/) → Sharp 리사이즈 → 썸네일 저장(hotels/thumbnails/)"

  filename         = local.image_resize_zip
  # zip 내용이 바뀔 때만 Lambda 업데이트
  source_code_hash = filebase64sha256(local.image_resize_zip)

  runtime = "nodejs20.x"
  handler = "index.handler"
  role    = aws_iam_role.lambda_image_resize_role.arn

  # 이미지 다운로드 + 처리 시간 고려 (booking-notification 30초보다 여유있게)
  timeout = 60

  # Sharp 이미지 처리는 메모리 필요 (128MB 부족, 512MB 권장)
  memory_size = 512

  environment {
    variables = {
      THUMBNAIL_WIDTH  = "400"
      THUMBNAIL_HEIGHT = "300"
      ORIGINAL_PREFIX  = "hotels/original/"
      THUMBNAIL_PREFIX = "hotels/thumbnails/"
      # 원본을 Azure Blob hotels/original/ 에도 동기화하기 위한 Secrets Manager 참조
      AZURE_BLOB_CONNECTION_STRING_SECRET_ARN = data.aws_secretsmanager_secret.azure_blob_connection_string.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_image_resize]

  tags = {
    Name      = "ThreeTier-Image-Resize"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 5. S3가 Lambda를 호출할 수 있도록 권한 부여
#    - S3 이벤트 알림은 Lambda를 직접 호출하므로
#      Lambda 리소스 정책에 s3.amazonaws.com 허용 필요
# ──────────────────────────────────────────────
resource "aws_lambda_permission" "allow_s3_invoke_image_resize" {
  statement_id  = "AllowS3InvokeImageResize"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resize.function_name
  principal     = "s3.amazonaws.com"
  # 이 버킷에서 오는 호출만 허용 (다른 버킷 악용 방지)
  source_arn    = aws_s3_bucket.uploads.arn
}

# ──────────────────────────────────────────────
# 6. Outputs
# ──────────────────────────────────────────────
output "image_resize_function_name" {
  description = "image-resize Lambda 함수 이름"
  value       = aws_lambda_function.image_resize.function_name
}

output "image_resize_function_arn" {
  description = "image-resize Lambda 함수 ARN"
  value       = aws_lambda_function.image_resize.arn
}
