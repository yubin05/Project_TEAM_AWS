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
dnf install -y git
git clone --filter=blob:none --sparse https://github.com/${var.github_owner}/${var.github_repo_name}.git /opt/app
cd /opt/app
git sparse-checkout set database
DB_PASSWORD="${var.db_password}" sudo -E bash database/scripts/mysql_install.sh
MYSQL_PASSWORD="${var.db_password}" bash database/scripts/run-seed.sh
touch /tmp/mysql_ready
EOF
}
