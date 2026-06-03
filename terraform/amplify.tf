# ── Amplify App ───────────────────────────────────────────────────────────────
# 프론트엔드 전용 — amplify.yml (appRoot: frontend) 기준으로 빌드
resource "aws_amplify_app" "frontend" {
  name         = "ThreeTier-Frontend"
  repository   = "https://github.com/${var.github_owner}/${var.github_repo_name}"
  access_token = var.github_token

  build_spec = file("${path.module}/../frontend/amplify.yml")

  environment_variables = {
    API_URL                   = aws_apigatewayv2_api.main.api_endpoint
    AMPLIFY_MONOREPO_APP_ROOT = "frontend"
    AMPLIFY_DIFF_DEPLOY       = var.amplify_force_deploy ? "false" : "true"
    AMPLIFY_DIFF_DEPLOY_ROOT  = "frontend"
  }

  # frontend/ 외 경로 변경 시 빌드 스킵 (CodePipeline과 역할 분리)
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }
}

# ── Amplify Branch (main) ──────────────────────────────────────────────────────
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = var.deploy_branch

  enable_auto_build = true
}

# ── 첫 배포 및 API URL 변경 시 자동 빌드 트리거 ──────────────────────────────
resource "null_resource" "amplify_build_trigger" {
  triggers = {
    api_url = aws_apigatewayv2_api.main.api_endpoint
  }

  provisioner "local-exec" {
    command = "aws amplify start-job --app-id ${aws_amplify_app.frontend.id} --branch-name ${var.deploy_branch} --job-type RELEASE --region ap-northeast-2 --profile ${var.aws_profile}"
  }

  depends_on = [aws_amplify_branch.main]
}
