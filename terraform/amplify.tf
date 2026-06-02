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
    AMPLIFY_DIFF_DEPLOY       = "true"
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
  branch_name = "main"

  enable_auto_build = true
}
