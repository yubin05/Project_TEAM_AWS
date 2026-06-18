# ── Route53 DR Failover ──────────────────────────────────────────────────────
# var.dr_subdomain.var.dr_root_domain (기본 www.vundle34.cloud) 에 대해
#   Primary  = AWS Amplify 프론트엔드 (헬스체크로 장애 감지)
#   Secondary = Azure Static Web App
# 의 CNAME failover 라우팅을 구성한다.
#
# www는 zone apex가 아닌 일반 레코드이므로 Primary/Secondary 모두 CNAME으로 구성 가능.

resource "aws_route53_zone" "dr" {
  name = var.dr_root_domain

  tags = { Name = "ThreeTier-DR-Zone" }
}

# ── AWS Amplify 커스텀 도메인 (ACM 인증서는 Amplify가 자동 발급/관리) ──────────
resource "aws_amplify_domain_association" "frontend" {
  app_id      = aws_amplify_app.frontend.id
  domain_name = var.dr_root_domain

  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = var.dr_subdomain
  }

  # true로 두면 ACM 인증서 검증 완료까지 apply가 블로킹됨 -> 아래 검증용
  # CNAME 레코드를 먼저 만들어야 하므로 false로 두고 단계적으로 적용
  wait_for_verification = false
}

# 참고: ACM 인증서 DNS 검증용 CNAME은 Amplify가 같은 계정의 Route53 zone을
# 자동으로 감지하여 직접 생성/관리하므로 terraform 리소스로 별도 정의하지 않음.

# ── Route53 Health Check (AWS Amplify 기본 도메인 기준) ────────────────────────
resource "aws_route53_health_check" "aws_frontend" {
  fqdn              = "${aws_amplify_branch.main.branch_name}.${aws_amplify_app.frontend.default_domain}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "ThreeTier-DR-AWS-HealthCheck" }
}

# ── www CNAME Failover (apply 2단계: 인증서 검증 완료 후 sub_domain.dns_record 사용 가능) ──
resource "aws_route53_record" "www_primary" {
  zone_id        = aws_route53_zone.dr.zone_id
  name           = var.dr_subdomain
  type           = "CNAME"
  ttl            = 60
  set_identifier = "aws-primary"
  records = [
    for sd in aws_amplify_domain_association.frontend.sub_domain :
    trimsuffix(split(" ", sd.dns_record)[2], ".")
    if sd.prefix == var.dr_subdomain
  ]

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.aws_frontend.id
}

resource "aws_route53_record" "www_secondary" {
  zone_id        = aws_route53_zone.dr.zone_id
  name           = var.dr_subdomain
  type           = "CNAME"
  ttl            = 60
  set_identifier = "azure-secondary"
  records        = [var.azure_frontend_endpoint]

  failover_routing_policy {
    type = "SECONDARY"
  }
}
