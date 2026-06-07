locals {
  ami_id = data.aws_ssm_parameter.al2023_ami.value
}


# ── MySQL EC2 ─────────────────────────────────────────────────────────────────
# enable_migration = false 로 변경 후 apply 하면 자동 삭제
resource "aws_instance" "mysql" {
  count = var.enable_migration ? 1 : 0
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_db.id
  vpc_security_group_ids = [aws_security_group.mysql.id]
  private_ip             = "10.1.3.10"
  tags = { Name = "ThreeTier-MySQL-EC2" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-MySQL-EC2
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail

# S3에서 스크립트 다운로드 (S3 VPC 엔드포인트 사용 — 외부 인터넷 불필요)
aws s3 cp s3://${aws_s3_bucket.uploads.bucket}/database/mysql_install.sh /tmp/mysql_install.sh
aws s3 cp s3://${aws_s3_bucket.uploads.bucket}/database/run-seed.sh /tmp/run-seed.sh
aws s3 cp s3://${aws_s3_bucket.uploads.bucket}/database/seed.sql /tmp/seed.sql
chmod +x /tmp/mysql_install.sh /tmp/run-seed.sh

DB_PASSWORD="${var.db_password}" bash /tmp/mysql_install.sh
MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD="${var.db_password}" bash /tmp/run-seed.sh
touch /tmp/mysql_ready
EOF
}
