# ============================================================
#  logs_alarms.tf
#  CloudWatch 알람 + SNS + SQS 모니터링
# ============================================================

# ── 1. SQS 큐 생성 ──────────────────────────────────────────
# booking-queue: 예약 확정 이메일 알림용
resource "aws_sqs_queue" "booking_queue" {
  name                       = "booking-queue"
  visibility_timeout_seconds = 300          # Lambda 처리 시간 고려 (5분)
  message_retention_seconds  = 86400        # 메시지 보관 1일
  receive_wait_time_seconds  = 20           # Long Polling (비용 절감)

  tags = { Name = "booking-queue" }
}

# rating-queue: 리뷰 생성/삭제 시 평점 갱신용
resource "aws_sqs_queue" "rating_queue" {
  name                       = "rating-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  tags = { Name = "rating-queue" }
}


# ── 2. SNS Topic (알람 배달 허브) ───────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "travel-app-alerts"
  tags = { Name = "TravelApp-Alerts" }
}

# 이메일 구독 — 설혜원 (확인 이메일 수신 후 클릭해야 활성화됨)
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "shw504@gmail.com"
}


# ── 3. ECS CPU 알람 (5개 서비스) ────────────────────────────
# 비유: 컨테이너 CPU가 70% 넘으면 소방 감지기처럼 SNS에 알림
locals {
  ecs_services = {
    auth    = "auth-service"
    hotel   = "hotel-service"
    booking = "booking-service"
    review  = "review-service"
    support = "support-service"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = local.ecs_services

  alarm_name          = "ECS-CPU-High-${each.value}"
  alarm_description   = "${each.value} CPU 사용률 70% 초과"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2          # 2번 연속 측정값이 초과될 때만 알람
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60         # 60초(1분) 단위 측정
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = each.value
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]  # 정상 복귀 시에도 알림

  tags = { Name = "ECS-CPU-High-${each.value}" }
}


# ── 4. Aurora CPU 알람 ──────────────────────────────────────
# Aurora는 RDS MySQL과 메트릭 이름 동일하지만 DBClusterIdentifier로 참조
resource "aws_cloudwatch_metric_alarm" "aurora_cpu_high" {
  alarm_name          = "Aurora-CPU-High"
  alarm_description   = "Aurora 클러스터 CPU 80% 초과"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "Aurora-CPU-High" }
}


# ── 5. Aurora 연결 수 알람 ──────────────────────────────────
# Aurora Serverless v2 max_capacity=4 기준 → 동시 연결 약 270개
# 80개 초과 시 경고 (여유 있게 설정)
resource "aws_cloudwatch_metric_alarm" "aurora_connections_high" {
  alarm_name          = "Aurora-Connections-High"
  alarm_description   = "Aurora 클러스터 DB 연결 수 80개 초과"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "Aurora-Connections-High" }
}


# ── 6. ALB 5xx 에러 알람 ────────────────────────────────────
# 서버 에러(500번대)가 1분에 10회 이상 발생하면 알람
resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "ALB-5xx-High"
  alarm_description   = "ALB 5xx 에러 1분에 10회 초과"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10

  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
  }

  alarm_actions             = [aws_sns_topic.alerts.arn]
  treat_missing_data        = "notBreaching"  # 데이터 없으면 정상으로 처리

  tags = { Name = "ALB-5xx-High" }
}


# ── 7. SQS 알람: booking-queue ──────────────────────────────
# 메시지가 100개 이상 쌓이면 "예약 처리가 밀리고 있어요!" 알람
resource "aws_cloudwatch_metric_alarm" "booking_queue_depth" {
  alarm_name          = "SQS-BookingQueue-Depth-High"
  alarm_description   = "booking-queue 메시지 100개 초과 — 예약 처리 지연 가능성"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 100

  dimensions = {
    QueueName = aws_sqs_queue.booking_queue.name
  }

  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"

  tags = { Name = "SQS-BookingQueue-Depth-High" }
}


# ── 8. SQS 알람: rating-queue ───────────────────────────────
# 메시지가 200개 이상 쌓이면 "평점 갱신이 밀리고 있어요!" 알람
resource "aws_cloudwatch_metric_alarm" "rating_queue_depth" {
  alarm_name          = "SQS-RatingQueue-Depth-High"
  alarm_description   = "rating-queue 메시지 200개 초과 — 평점 갱신 지연 가능성"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 200

  dimensions = {
    QueueName = aws_sqs_queue.rating_queue.name
  }

  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"

  tags = { Name = "SQS-RatingQueue-Depth-High" }
}
