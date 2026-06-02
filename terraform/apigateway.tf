# ── HTTP API ──────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_api" "main" {
  name          = "ThreeTier-HTTP-API"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }

  tags = { Name = "ThreeTier-HTTP-API" }
}

# ── VPC Link → Internal ALB ───────────────────────────────────────────────────
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "ThreeTier-VPC-Link"
  security_group_ids = [aws_security_group.alb.id]
  subnet_ids         = [aws_subnet.private_backend.id, aws_subnet.private_backend_2.id]
  tags               = { Name = "ThreeTier-VPC-Link" }
}

# ── 서비스별 Integration (API Gateway → ALB 서비스별 리스너) ─────────────────
resource "aws_apigatewayv2_integration" "auth" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.auth.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  request_parameters = { "overwrite:path" = "$request.path" }
}

resource "aws_apigatewayv2_integration" "hotel" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.hotel.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  request_parameters = { "overwrite:path" = "$request.path" }
}

resource "aws_apigatewayv2_integration" "booking" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.booking.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  request_parameters = { "overwrite:path" = "$request.path" }
}

resource "aws_apigatewayv2_integration" "review" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = aws_lb_listener.review.arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
  request_parameters = { "overwrite:path" = "$request.path" }
}

locals {
  int_auth    = "integrations/${aws_apigatewayv2_integration.auth.id}"
  int_hotel   = "integrations/${aws_apigatewayv2_integration.hotel.id}"
  int_booking = "integrations/${aws_apigatewayv2_integration.booking.id}"
  int_review  = "integrations/${aws_apigatewayv2_integration.review.id}"
  # TODO: Cognito 설정 완료 후 각 인증 필요 라우트에 아래 추가
  # authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  # authorization_type = "JWT"
}

# ── auth-service ──────────────────────────────────────────────────────────────

# 공개
resource "aws_apigatewayv2_route" "auth_login" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/login"
  target    = local.int_auth
}

resource "aws_apigatewayv2_route" "auth_register" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/register"
  target    = local.int_auth
}

# 인증 필요
resource "aws_apigatewayv2_route" "auth_profile_get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /auth/profile"
  target    = local.int_auth
}

resource "aws_apigatewayv2_route" "auth_profile_put" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "PUT /auth/profile"
  target    = local.int_auth
}

resource "aws_apigatewayv2_route" "auth_password" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "PUT /auth/password"
  target    = local.int_auth
}

# ── hotel-service ─────────────────────────────────────────────────────────────

# 공개
resource "aws_apigatewayv2_route" "hotels_featured" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/featured"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_regions" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/regions"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_search" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/search"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_detail" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/{id}"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_room_detail" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/{hotelId}/rooms/{roomId}"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_video_status" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/{id}/video-status"
  target    = local.int_hotel
}

# 인증 필요
resource "aws_apigatewayv2_route" "hotels_mine" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/mine"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_create" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /hotels"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_update" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "PUT /hotels/{id}"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_room_create" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /hotels/{hotelId}/rooms"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_video_upload_url" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /hotels/{id}/video-upload-url"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "hotels_video_url" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /hotels/{id}/video-url"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "wishlist_toggle" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /wishlist/{hotelId}"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "wishlist_get" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /wishlist"
  target    = local.int_hotel
}

resource "aws_apigatewayv2_route" "recommend" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /recommend"
  target    = local.int_hotel
}

# ── booking-service ───────────────────────────────────────────────────────────

# 인증 필요
resource "aws_apigatewayv2_route" "bookings_create" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /bookings"
  target    = local.int_booking
}

resource "aws_apigatewayv2_route" "bookings_host" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /bookings/host"
  target    = local.int_booking
}

resource "aws_apigatewayv2_route" "bookings_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /bookings"
  target    = local.int_booking
}

resource "aws_apigatewayv2_route" "bookings_detail" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /bookings/{id}"
  target    = local.int_booking
}

resource "aws_apigatewayv2_route" "bookings_cancel" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "DELETE /bookings/{id}"
  target    = local.int_booking
}

# ── review-service ────────────────────────────────────────────────────────────

# 공개
resource "aws_apigatewayv2_route" "hotel_reviews_list" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /hotels/{hotelId}/reviews"
  target    = local.int_review
}

# 인증 필요
resource "aws_apigatewayv2_route" "reviews_create" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /reviews"
  target    = local.int_review
}

resource "aws_apigatewayv2_route" "reviews_delete" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "DELETE /reviews/{id}"
  target    = local.int_review
}

# ── Stage ─────────────────────────────────────────────────────────────────────
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
  tags        = { Name = "ThreeTier-API-Stage" }
}
