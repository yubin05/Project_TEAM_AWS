# ================================================================
# 파일 경로 : terraform/iam_lambda_image_resize.tf
# 용도      : image-resize Lambda 실행 IAM Role + Policy 생성
# 선행 조건 : s3.tf (uploads 버킷) apply 완료
# ================================================================

# ──────────────────────────────────────────────
# 1. Trust Policy — Lambda만 이 Role 사용 가능
# ──────────────────────────────────────────────
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

# ──────────────────────────────────────────────
# 2. Lambda Execution Role
# ──────────────────────────────────────────────
resource "aws_iam_role" "lambda_image_resize_role" {
  name               = "ThreeTier-Lambda-ImageResize-Role"
  assume_role_policy = data.aws_iam_policy_document.lambda_image_resize_assume.json

  tags = {
    Name      = "ThreeTier-Lambda-ImageResize-Role"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 3. 권한 Policy 정의 (최소 권한 원칙)
# ──────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_image_resize_policy" {

  # ① CloudWatch Logs — 실행 로그 기록
  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/ThreeTier-Image-Resize:*"
    ]
  }

  # ② S3 원본 이미지 읽기 (hotels/original/ prefix만)
  statement {
    sid     = "AllowS3GetOriginal"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.uploads.arn}/hotels/original/*"
    ]
  }

  # ③ S3 썸네일 쓰기 (hotels/thumbnails/ prefix만)
  statement {
    sid     = "AllowS3PutThumbnail"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.uploads.arn}/hotels/thumbnails/*"
    ]
  }
}

# ──────────────────────────────────────────────
# 4. Policy 문서 → 실제 IAM Policy 리소스
# ──────────────────────────────────────────────
resource "aws_iam_policy" "lambda_image_resize_policy" {
  name        = "ThreeTier-Lambda-ImageResize-Policy"
  description = "image-resize Lambda 최소 권한 (S3 원본 읽기 + 썸네일 쓰기 + CloudWatch)"
  policy      = data.aws_iam_policy_document.lambda_image_resize_policy.json

  tags = {
    Name      = "ThreeTier-Lambda-ImageResize-Policy"
    ManagedBy = "terraform"
  }
}

# ──────────────────────────────────────────────
# 5. Role에 Policy 부착
# ──────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "lambda_image_resize" {
  role       = aws_iam_role.lambda_image_resize_role.name
  policy_arn = aws_iam_policy.lambda_image_resize_policy.arn
}
