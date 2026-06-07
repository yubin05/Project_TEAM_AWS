# ================================================================
# 파일 경로 : terraform/lambda_image_resize.tf
# 용도      : image-resize Lambda 생성 + S3 이벤트 트리거 연결
# 선행 조건 : iam_lambda_image_resize.tf / s3.tf apply 완료
#             lambda/image-resize/index.mjs + package.json 존재
# ================================================================

# ──────────────────────────────────────────────
# 1. Lambda 배포용 zip 생성 (node_modules 포함)
#
#    ⚠ terraform apply 전에 아래 명령을 수동으로 먼저 실행해야 함:
#
#    PowerShell:
#      cd "g:\내 드라이브\Project_TEAM_AWS\lambda\image-resize"
#      $env:npm_config_platform = "linux"
#      $env:npm_config_arch = "x64"
#      npm install
#
#    이유: Google Drive 경로(한글 포함)에서 null_resource local-exec 실행 시
#          tar EBADF 오류 발생 — terraform 외부에서 미리 설치하는 방식으로 우회
# ──────────────────────────────────────────────
data "archive_file" "image_resize" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/image-resize"
  output_path = "${path.module}/../lambda/image-resize.zip"
}

# ──────────────────────────────────────────────
# 4. Lambda 함수 생성
# ──────────────────────────────────────────────
resource "aws_lambda_function" "image_resize" {
  function_name = "ThreeTier-Image-Resize"
  description   = "S3 호텔 이미지 업로드(hotels/original/) → Sharp 리사이즈 → 썸네일 저장(hotels/thumbnails/)"

  filename         = data.archive_file.image_resize.output_path
  # zip 내용이 바뀔 때만 Lambda 업데이트
  source_code_hash = data.archive_file.image_resize.output_base64sha256

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
