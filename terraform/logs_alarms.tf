# ============================================================
#  logs_alarms.tf
#  CloudWatch 알람 + SNS 모니터링
# ============================================================

# ── 1. SNS Topic (알람 배달 허브) ───────────────────────────
resource "aws_sns_topic" "alerts" {
  name = "travel-app-alerts"
  tags = { Name = "TravelApp-Alerts" }
}

# 이메일 구독 — 본인 (확인 이메일 수신 후 클릭해야 활성화됨)
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


# ── 2. ECS CPU 알람 (5개 서비스) ────────────────────────────
# 비유: 컨테이너 CPU가 70% 넘으면 소방 감지기처럼 SNS에 알림
locals {
  ecs_service_names = {
    auth    = "auth-service"
    hotel   = "hotel-service"
    booking = "booking-service"
    review  = "review-service"
    support = "support-service"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  for_each = local.ecs_service_names

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


# ── 3. Aurora CPU 알람 ──────────────────────────────────────
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


# ── 4. Aurora 연결 수 알람 ──────────────────────────────────
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


# ── 5. ALB 5xx 에러 알람 ────────────────────────────────────
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


# ── 6. SQS 알람: booking-queue ──────────────────────────────
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


# ── 7. SQS 알람: rating-queue ───────────────────────────────
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


# ── booking-queue 메시지 체류 시간 알람 ──────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "sqs_booking_age" {
  alarm_name          = "SQS-BookingQueue-OldestMessageAge"
  alarm_description   = "booking-queue 최오래된 메시지 5분 초과 — 예약 처리 지연"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 300
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.booking_queue.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "SQS-BookingQueue-OldestMessageAge" }
}


# ── rating-queue 메시지 체류 시간 알람 ───────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "sqs_rating_age" {
  alarm_name          = "SQS-RatingQueue-OldestMessageAge"
  alarm_description   = "rating-queue 최오래된 메시지 5분 초과 — 평점 처리 지연"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 300
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.rating_queue.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "SQS-RatingQueue-OldestMessageAge" }
}


# ── 8. Metric Filter 기반 알람 ──────────────────────────────────────────────
# CloudWatch Logs → Metric Filter → CloudWatch Alarm → SNS → Slack

# ECS 5개 서비스 로그에서 ERROR/CRITICAL 키워드 카운트
resource "aws_cloudwatch_log_metric_filter" "ecs_error" {
  for_each       = local.ecs_service_names
  name           = "ecs-${each.key}-error-filter"
  log_group_name = "/ecs/${each.value}"
  pattern        = "?ERROR ?CRITICAL"

  metric_transformation {
    name          = "ECSErrorCount-${each.value}"
    namespace     = "ThreeTier/ApplicationLogs"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_error_rate" {
  for_each = local.ecs_service_names

  alarm_name          = "ECS-ErrorRate-${each.value}"
  alarm_description   = "${each.value} ERROR/CRITICAL 로그 5분간 10건 초과"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ECSErrorCount-${each.value}"
  namespace           = "ThreeTier/ApplicationLogs"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "ECS-ErrorRate-${each.value}" }
}

# RDS Slow Query Metric Filter
resource "aws_cloudwatch_log_metric_filter" "rds_slow_query" {
  name           = "rds-slow-query-filter"
  log_group_name = "/aws/rds/cluster/threetier-aurora-cluster/slowquery"
  pattern        = "Query_time"

  metric_transformation {
    name          = "RDSSlowQueryCount"
    namespace     = "ThreeTier/RDSLogs"
    value         = "1"
    default_value = "0"
  }

  depends_on = [aws_cloudwatch_log_group.rds_slowquery]
}

resource "aws_cloudwatch_metric_alarm" "rds_slow_query" {
  alarm_name          = "RDS-SlowQuery-High"
  alarm_description   = "RDS Slow Query 5분간 5건 초과"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RDSSlowQueryCount"
  namespace           = "ThreeTier/RDSLogs"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = { Name = "RDS-SlowQuery-High" }
}


# ── 9. DMS 알람 ─────────────────────────────────────────────────────────────
# enable_migration = true 일 때만 생성 (DMS 리소스 생애주기와 동일)

# Full Load 처리량 급감 — IDC → Aurora 마이그레이션 지연 감지
resource "aws_cloudwatch_metric_alarm" "dms_full_load_throughput_low" {
  count = var.enable_migration ? 1 : 0

  alarm_name          = "DMS-FullLoad-Throughput-Low"
  alarm_description   = "DMS Full Load 복제 처리량 급감 — IDC→Aurora 마이그레이션 지연 가능성"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FullLoadThroughputRowsTarget"
  namespace           = "AWS/DMS"
  period              = 60
  statistic           = "Average"
  threshold           = 100  # 100 rows/sec 미만이면 알람

  dimensions = {
    ReplicationTaskIdentifier = aws_dms_replication_task.full_load[0].replication_task_id
  }

  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"

  tags = { Name = "DMS-FullLoad-Throughput-Low" }
}

# CDC 복제 지연 — Aurora → Azure 실시간 동기화 지연 감지
resource "aws_cloudwatch_metric_alarm" "dms_cdc_latency_high" {
  count = local.cdc_enabled ? 1 : 0

  alarm_name          = "DMS-CDC-SourceLatency-High"
  alarm_description   = "DMS CDC 소스 지연 60초 초과 — Aurora→Azure 실시간 복제 지연"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CDCLatencySource"
  namespace           = "AWS/DMS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 60

  dimensions = {
    ReplicationTaskIdentifier = aws_dms_replication_task.aurora_to_azure[0].replication_task_id
  }

  alarm_actions      = [aws_sns_topic.alerts.arn]
  ok_actions         = [aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"

  tags = { Name = "DMS-CDC-SourceLatency-High" }
}