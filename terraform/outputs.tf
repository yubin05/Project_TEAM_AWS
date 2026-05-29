output "frontend_url" {
  description = "프론트엔드 접속 URL (브라우저)"
  value       = "http://${aws_eip.frontend.public_ip}"
}

output "frontend_public_ip" {
  description = "Frontend EC2 퍼블릭 IP"
  value       = aws_eip.frontend.public_ip
}

output "nat_instance_public_ip" {
  description = "NAT Instance 퍼블릭 IP"
  value       = aws_eip.nat.public_ip
}

output "mysql_private_ip" {
  description = "MySQL EC2 프라이빗 IP (포트 3306)"
  value       = aws_instance.mysql.private_ip
}

output "auth_private_ip" {
  description = "Auth Service EC2 프라이빗 IP (포트 3001)"
  value       = aws_instance.auth.private_ip
}

output "hotel_private_ip" {
  description = "Hotel Service EC2 프라이빗 IP (포트 3002, ElasticMQ 9324)"
  value       = aws_instance.hotel.private_ip
}

output "booking_private_ip" {
  description = "Booking Service EC2 프라이빗 IP (포트 3003)"
  value       = aws_instance.booking.private_ip
}

output "review_private_ip" {
  description = "Review Service EC2 프라이빗 IP (포트 3004)"
  value       = aws_instance.review.private_ip
}
