resource "aws_security_group" "alb" {
  name        = "ThreeTier-ALB-SG"
  description = "Internal ALB Security Group"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ThreeTier-ALB-SG" }

  ingress {
    description = "HTTP from VPC (API Gateway VPC Link)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "auth-service"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "hotel-service"
    from_port   = 3002
    to_port     = 3002
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "booking-service"
    from_port   = 3003
    to_port     = 3003
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "review-service"
    from_port   = 3004
    to_port     = 3004
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Internal ALB ─────────────────────────────────────────────────────────────
resource "aws_lb" "internal" {
  name               = "ThreeTier-ALB-Internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
  tags               = { Name = "ThreeTier-ALB-Internal" }

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "alb-access-logs"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.logs]
}

# ── Target Groups (Blue) ──────────────────────────────────────────────────────
resource "aws_lb_target_group" "auth" {
  name        = "ThreeTier-Auth-TG"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Auth-TG" }
}

resource "aws_lb_target_group" "hotel" {
  name        = "ThreeTier-Hotel-TG"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Hotel-TG" }
}

resource "aws_lb_target_group" "booking" {
  name        = "ThreeTier-Booking-TG"
  port        = 3003
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Booking-TG" }
}

resource "aws_lb_target_group" "review" {
  name        = "ThreeTier-Review-TG"
  port        = 3004
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Review-TG" }
}

# ── Green Target Groups (Blue/Green 배포용) ───────────────────────────────────
resource "aws_lb_target_group" "auth_green" {
  name        = "ThreeTier-Auth-TG-Green"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Auth-TG-Green" }
}

resource "aws_lb_target_group" "hotel_green" {
  name        = "ThreeTier-Hotel-TG-Green"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Hotel-TG-Green" }
}

resource "aws_lb_target_group" "booking_green" {
  name        = "ThreeTier-Booking-TG-Green"
  port        = 3003
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Booking-TG-Green" }
}

resource "aws_lb_target_group" "review_green" {
  name        = "ThreeTier-Review-TG-Green"
  port        = 3004
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }
  tags = { Name = "ThreeTier-Review-TG-Green" }
}

# ── 서비스별 리스너 (CodeDeploy Blue/Green이 리스너 단위로 TG 전환) ────────────
# lifecycle ignore_changes = [default_action] — CodeDeploy가 TG 전환 후 terraform이 덮어쓰지 않도록

resource "aws_lb_listener" "auth" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 3001
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }
  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener" "hotel" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 3002
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hotel.arn
  }
  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener" "booking" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 3003
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.booking.arn
  }
  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_lb_listener" "review" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 3004
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.review.arn
  }
  lifecycle {
    ignore_changes = [default_action]
  }
}

# ── 포트 80 폴백 리스너 (미매칭 요청 404) ─────────────────────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}
