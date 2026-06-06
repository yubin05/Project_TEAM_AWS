# ── ECS Cluster ──────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "ThreeTier-Cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "ThreeTier-Cluster" }
}


# ── CloudWatch Log Groups ─────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "auth" {
  name              = "/ecs/auth-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "hotel" {
  name              = "/ecs/hotel-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "booking" {
  name              = "/ecs/booking-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "review" {
  name              = "/ecs/review-service"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "support" {
  name              = "/ecs/support-service"
  retention_in_days = 30
}

# ── Task Definitions ──────────────────────────────────────────────────────────
# NOTE: ECR 이미지는 CodePipeline으로 푸시한 후 ECS 서비스가 정상 기동됩니다.

resource "aws_ecs_task_definition" "auth" {
  family                   = "auth-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  # TODO: Secrets Manager 설정 완료 후 아래 작업 필요
  # 1. task_role_arn 주석 해제 (aws_iam_role.ecs_task 리소스 복구 필요)
  # 2. APP_MODE = "local" → "aws" 로 변경 (4개 서비스 모두)

  container_definitions = jsonencode([{
    name  = "auth-service"
    image = "${aws_ecr_repository.auth.repository_url}:latest"
    portMappings = [{ containerPort = 3001, protocol = "tcp" }]
    environment = [
      { name = "APP_MODE",        value = "local" },
      { name = "PORT",            value = "3001" },
      { name = "DB_HOST",         value = aws_rds_cluster.main.endpoint },
      { name = "DB_PORT",         value = "3306" },
      { name = "DB_USER",         value = "admin" },
      { name = "DB_PASSWORD",     value = var.db_password },
      { name = "DB_NAME",         value = "auth_db" },
      { name = "JWT_SECRET",      value = var.jwt_secret },
      { name = "INTERNAL_SECRET", value = var.internal_secret },
      { name = "AWS_REGION",      value = var.aws_region }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/auth-service"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "hotel" {
  family                   = "hotel-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  # TODO: Secrets Manager 설정 완료 후 아래 작업 필요
  # 1. task_role_arn 주석 해제 (aws_iam_role.ecs_task 리소스 복구 필요)
  # 2. APP_MODE = "local" → "aws" 로 변경 (4개 서비스 모두)

  container_definitions = jsonencode([{
    name  = "hotel-service"
    image = "${aws_ecr_repository.hotel.repository_url}:latest"
    portMappings = [{ containerPort = 3002, protocol = "tcp" }]
    environment = [
      { name = "APP_MODE",            value = "local" },
      { name = "PORT",                value = "3002" },
      { name = "DB_HOST",             value = aws_rds_cluster.main.endpoint },
      { name = "DB_PORT",             value = "3306" },
      { name = "DB_USER",             value = "admin" },
      { name = "DB_PASSWORD",         value = var.db_password },
      { name = "DB_NAME",             value = "hotel_db" },
      { name = "JWT_SECRET",          value = var.jwt_secret },
      { name = "INTERNAL_SECRET",     value = var.internal_secret },
      { name = "AWS_REGION",          value = var.aws_region },
      { name = "BOOKING_SERVICE_URL", value = "http://${aws_lb.internal.dns_name}" },
      { name = "REVIEW_SERVICE_URL",  value = "http://${aws_lb.internal.dns_name}" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/hotel-service"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "booking" {
  family                   = "booking-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  # TODO: Secrets Manager 설정 완료 후 아래 작업 필요
  # 1. task_role_arn 주석 해제 (aws_iam_role.ecs_task 리소스 복구 필요)
  # 2. APP_MODE = "local" → "aws" 로 변경 (4개 서비스 모두)

  container_definitions = jsonencode([{
    name  = "booking-service"
    image = "${aws_ecr_repository.booking.repository_url}:latest"
    portMappings = [{ containerPort = 3003, protocol = "tcp" }]
    environment = [
      { name = "APP_MODE",              value = "local" },
      { name = "PORT",                  value = "3003" },
      { name = "DB_HOST",               value = aws_rds_cluster.main.endpoint },
      { name = "DB_PORT",               value = "3306" },
      { name = "DB_USER",               value = "admin" },
      { name = "DB_PASSWORD",           value = var.db_password },
      { name = "DB_NAME",               value = "booking_db" },
      { name = "JWT_SECRET",            value = var.jwt_secret },
      { name = "INTERNAL_SECRET",       value = var.internal_secret },
      { name = "AWS_REGION",            value = var.aws_region },
      { name = "HOTEL_SERVICE_URL",     value = "http://${aws_lb.internal.dns_name}" },
      { name = "SQS_BOOKING_QUEUE_URL", value = aws_sqs_queue.booking_queue.url }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/booking-service"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "review" {
  family                   = "review-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  # TODO: Secrets Manager 설정 완료 후 아래 작업 필요
  # 1. task_role_arn 주석 해제 (aws_iam_role.ecs_task 리소스 복구 필요)
  # 2. APP_MODE = "local" → "aws" 로 변경 (4개 서비스 모두)

  container_definitions = jsonencode([{
    name  = "review-service"
    image = "${aws_ecr_repository.review.repository_url}:latest"
    portMappings = [{ containerPort = 3004, protocol = "tcp" }]
    environment = [
      { name = "APP_MODE",             value = "local" },
      { name = "PORT",                 value = "3004" },
      { name = "DB_HOST",              value = aws_rds_cluster.main.endpoint },
      { name = "DB_PORT",              value = "3306" },
      { name = "DB_USER",              value = "admin" },
      { name = "DB_PASSWORD",          value = var.db_password },
      { name = "DB_NAME",              value = "review_db" },
      { name = "JWT_SECRET",           value = var.jwt_secret },
      { name = "INTERNAL_SECRET",      value = var.internal_secret },
      { name = "AWS_REGION",           value = var.aws_region },
      { name = "BOOKING_SERVICE_URL",  value = "http://${aws_lb.internal.dns_name}" },
      { name = "HOTEL_SERVICE_URL",    value = "http://${aws_lb.internal.dns_name}" },
      { name = "SQS_RATING_QUEUE_URL", value = aws_sqs_queue.rating_queue.url }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/review-service"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_task_definition" "support" {
  family                   = "support-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_support.arn

  container_definitions = jsonencode([{
    name  = "support-service"
    image = "${aws_ecr_repository.support.repository_url}:latest"
    portMappings = [{ containerPort = 3005, protocol = "tcp" }]
    environment = [
      { name = "APP_MODE",        value = "local" },
      { name = "PORT",            value = "3005" },
      { name = "DB_HOST",         value = aws_rds_cluster.main.endpoint },
      { name = "DB_PORT",         value = "3306" },
      { name = "DB_USER",         value = "admin" },
      { name = "DB_PASSWORD",     value = var.db_password },
      { name = "DB_NAME",         value = "support_db" },
      { name = "JWT_SECRET",        value = var.jwt_secret },
      { name = "INTERNAL_SECRET",   value = var.internal_secret },
      { name = "AWS_REGION",        value = var.aws_region },
      { name = "S3_UPLOADS_BUCKET", value = aws_s3_bucket.uploads.id }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/support-service"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# ── ECS Services ──────────────────────────────────────────────────────────────
resource "aws_ecs_service" "auth" {
  name            = "auth-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth.arn
    container_name   = "auth-service"
    container_port   = 3001
  }

  wait_for_steady_state = false
  depends_on            = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

resource "aws_ecs_service" "hotel" {
  name            = "hotel-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hotel.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hotel.arn
    container_name   = "hotel-service"
    container_port   = 3002
  }

  wait_for_steady_state = false
  depends_on            = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

resource "aws_ecs_service" "booking" {
  name            = "booking-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.booking.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.booking.arn
    container_name   = "booking-service"
    container_port   = 3003
  }

  wait_for_steady_state = false
  depends_on            = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

resource "aws_ecs_service" "review" {
  name            = "review-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.review.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.review.arn
    container_name   = "review-service"
    container_port   = 3004
  }

  wait_for_steady_state = false
  depends_on            = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}

resource "aws_ecs_service" "support" {
  name            = "support-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.support.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.support.arn
    container_name   = "support-service"
    container_port   = 3005
  }

  wait_for_steady_state = false
  depends_on            = [aws_lb_listener.http]

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}
