output "mysql_private_ip" {
  description = "MySQL EC2 프라이빗 IP (DMS 소스) — enable_migration = false 시 null"
  value       = var.enable_migration ? aws_instance.mysql[0].private_ip : null
}

output "api_gateway_endpoint" {
  description = "API Gateway 엔드포인트 URL (Amplify API_URL에 설정)"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "alb_internal_dns" {
  description = "Internal ALB DNS (서비스 간 통신용)"
  value       = aws_lb.internal.dns_name
}

output "rds_endpoint" {
  description = "Aurora 클러스터 Writer 엔드포인트 (DMS 타깃)"
  value       = aws_rds_cluster.main.endpoint
}

output "rds_reader_endpoint" {
  description = "Aurora 클러스터 Reader 엔드포인트 (읽기 전용)"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "ecr_auth_url" {
  description = "ECR auth-service URL"
  value       = aws_ecr_repository.auth.repository_url
}

output "ecr_hotel_url" {
  description = "ECR hotel-service URL"
  value       = aws_ecr_repository.hotel.repository_url
}

output "ecr_booking_url" {
  description = "ECR booking-service URL"
  value       = aws_ecr_repository.booking.repository_url
}

output "ecr_review_url" {
  description = "ECR review-service URL"
  value       = aws_ecr_repository.review.repository_url
}

output "dr_zone_name_servers" {
  description = "Route53 DR hosted zone NS — Gabia에서 var.dr_root_domain(vundle34.cloud) 도메인 전체 네임서버로 위임"
  value       = aws_route53_zone.dr.name_servers
}

output "amplify_default_domain" {
  description = "Amplify 기본 도메인 (failover primary 후보)"
  value       = aws_amplify_app.frontend.default_domain
}
