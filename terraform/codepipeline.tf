
# ── CodeDeploy 앱 ─────────────────────────────────────────────────────────────
resource "aws_codedeploy_app" "main" {
  compute_platform = "ECS"
  name             = "ThreeTier-TravelApp"
}

# ── CodeDeploy 배포그룹 4개 ───────────────────────────────────────────────────
resource "aws_codedeploy_deployment_group" "auth" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "auth-service-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.auth.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.auth.arn]
      }
      target_group { name = aws_lb_target_group.auth.name }
      target_group { name = aws_lb_target_group.auth_green.name }
    }
  }
}

resource "aws_codedeploy_deployment_group" "hotel" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "hotel-service-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.hotel.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.hotel.arn]
      }
      target_group { name = aws_lb_target_group.hotel.name }
      target_group { name = aws_lb_target_group.hotel_green.name }
    }
  }
}

resource "aws_codedeploy_deployment_group" "booking" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "booking-service-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.booking.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.booking.arn]
      }
      target_group { name = aws_lb_target_group.booking.name }
      target_group { name = aws_lb_target_group.booking_green.name }
    }
  }
}

resource "aws_codedeploy_deployment_group" "review" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "review-service-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.review.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.review.arn]
      }
      target_group { name = aws_lb_target_group.review.name }
      target_group { name = aws_lb_target_group.review_green.name }
    }
  }
}

resource "aws_codedeploy_deployment_group" "support" {
  app_name               = aws_codedeploy_app.main.name
  deployment_group_name  = "support-service-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }
    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = aws_ecs_service.support.name
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [aws_lb_listener.support.arn]
      }
      target_group { name = aws_lb_target_group.support.name }
      target_group { name = aws_lb_target_group.support_green.name }
    }
  }
}

# ── S3 아티팩트 버킷 ──────────────────────────────────────────────────────────
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "threetier-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "ThreeTier-Pipeline-Artifacts" }
}

resource "aws_s3_bucket_lifecycle_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    id     = "delete-old-artifacts"
    status = "Enabled"
    filter {}
    expiration { days = 30 }
  }
}

data "aws_caller_identity" "current" {}

# ── CodeBuild 프로젝트 ────────────────────────────────────────────────────────
resource "aws_codebuild_project" "main" {
  name          = "ThreeTier-Build"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  source {
    type      = "CODEPIPELINE"
    buildspec = "backend/buildspec.yml"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "ECR_REGISTRY"
      value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    }
    environment_variable {
      name  = "EXECUTION_ROLE_ARN"
      value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ThreeTier-ECS-TaskExecution-Role"
    }
    environment_variable {
      name  = "DB_HOST"
      value = aws_rds_cluster.main.endpoint
    }
    environment_variable {
      name  = "DB_PASSWORD"
      value = var.db_password
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "JWT_SECRET"
      value = var.jwt_secret
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "INTERNAL_SECRET"
      value = var.internal_secret
      type  = "PLAINTEXT"
    }
    environment_variable {
      name  = "ALB_DNS"
      value = aws_lb.internal.dns_name
    }
    environment_variable {
      name  = "SQS_QUEUE_URL"
      value = aws_sqs_queue.booking_notification.url
    }
    environment_variable {
      name  = "S3_UPLOADS_BUCKET"
      value = aws_s3_bucket.uploads.id
    }
    environment_variable {
      name  = "SUPPORT_TASK_ROLE_ARN"
      value = aws_iam_role.ecs_task_support.arn
    }
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}

# ── CodePipeline V2 ───────────────────────────────────────────────────────────
resource "aws_codepipeline" "main" {
  name           = "ThreeTier-Pipeline"
  role_arn       = aws_iam_role.codepipeline.arn
  pipeline_type  = "V2"

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  trigger {
    provider_type = "CodeStarSourceConnection"
    git_configuration {
      source_action_name = "Source"
      push {
        branches { includes = [var.deploy_branch] }
        file_paths { includes = ["backend/**"] }
      }
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:${var.aws_region}:${data.aws_caller_identity.current.account_id}:connection/${var.github_connection_uuid}"
        FullRepositoryId = "${var.github_owner}/${var.github_repo_name}"
        BranchName       = var.deploy_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.main.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy-Auth"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      run_order       = 1
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.auth.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     ="auth-service/taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            ="auth-service/appspec.yaml"
      }
    }

    action {
      name            = "Deploy-Hotel"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      run_order       = 1
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.hotel.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     ="hotel-service/taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            ="hotel-service/appspec.yaml"
      }
    }

    action {
      name            = "Deploy-Booking"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      run_order       = 1
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.booking.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     ="booking-service/taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            ="booking-service/appspec.yaml"
      }
    }

    action {
      name            = "Deploy-Review"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      run_order       = 1
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.review.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     ="review-service/taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            ="review-service/appspec.yaml"
      }
    }

    action {
      name            = "Deploy-Support"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      run_order       = 1
      input_artifacts = ["build_output"]
      configuration = {
        ApplicationName                = aws_codedeploy_app.main.name
        DeploymentGroupName            = aws_codedeploy_deployment_group.support.deployment_group_name
        TaskDefinitionTemplateArtifact = "build_output"
        TaskDefinitionTemplatePath     ="support-service/taskdef.json"
        AppSpecTemplateArtifact        = "build_output"
        AppSpecTemplatePath            ="support-service/appspec.yaml"
      }
    }
  }
}