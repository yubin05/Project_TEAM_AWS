# locals {
#   ecs_services = {
#     auth    = aws_ecs_service.auth.name
#     hotel   = aws_ecs_service.hotel.name
#     booking = aws_ecs_service.booking.name
#     review  = aws_ecs_service.review.name
#     support = aws_ecs_service.support.name
#   }
# }

# ── Auto Scaling Targets ───────────────────────────────────────────────────────
resource "aws_appautoscaling_target" "ecs" {
  for_each           = local.ecs_service_names
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${each.value}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 4

  depends_on = [
    aws_ecs_service.auth,
    aws_ecs_service.hotel,
    aws_ecs_service.booking,
    aws_ecs_service.review,
    aws_ecs_service.support,
  ]
}

# ── CPU 기반 스케일링 (60% 목표) ──────────────────────────────────────────────
resource "aws_appautoscaling_policy" "ecs_cpu" {
  for_each           = local.ecs_service_names
  name               = "ThreeTier-${each.key}-CPU-ScalingPolicy"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = 60.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# ── 메모리 기반 스케일링 (70% 목표) ──────────────────────────────────────────
resource "aws_appautoscaling_policy" "ecs_memory" {
  for_each           = local.ecs_service_names
  name               = "ThreeTier-${each.key}-Memory-ScalingPolicy"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id
  scalable_dimension = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
