resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/threetier"
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "lambda_booking_notification" {
  name              = "/aws/lambda/booking-notification"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_image_resize" {
  name              = "/aws/lambda/image-resize"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "lambda_cognito_post_confirm" {
  name              = "/aws/lambda/cognito-post-confirm"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/threetier-http-api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-threetier"
  retention_in_days = 30
}
