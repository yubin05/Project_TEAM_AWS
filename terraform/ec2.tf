locals {
  ami_id = data.aws_ssm_parameter.al2023_ami.value
}

# ── EIP ─────────────────────────────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip_association" "nat" {
  instance_id   = aws_instance.nat.id
  allocation_id = aws_eip.nat.id
}

resource "aws_eip" "frontend" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]
}

resource "aws_eip_association" "frontend" {
  instance_id   = aws_instance.frontend.id
  allocation_id = aws_eip.frontend.id
}

# ── NAT Instance ─────────────────────────────────────────────────────────────
# Private IP: 10.1.1.100 | source_dest_check=false | iptables MASQUERADE
resource "aws_instance" "nat" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nat_instance.id]
  private_ip             = "10.1.1.100"
  source_dest_check      = false

  tags = { Name = "ThreeTier-NATInstance" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-NATInstance
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail
IFACE="$(ip route show default | awk '/default/ {print $5; exit}')"
dnf install -y iptables-services
systemctl enable --now iptables
cat > /etc/sysctl.d/90-nat.conf << 'SYSEOF'
net.ipv4.ip_forward=1
SYSEOF
sysctl --system
/sbin/iptables -t nat -F
/sbin/iptables -F FORWARD
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
service iptables save
EOF
}

# ── MySQL EC2 ─────────────────────────────────────────────────────────────────
# Private IP: 10.1.3.10 | 역할: MySQL 8.0 설치 + 4개 DB 초기화 + 시드 데이터
resource "aws_instance" "mysql" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_db.id
  vpc_security_group_ids = [aws_security_group.mysql.id]
  private_ip             = "10.1.3.10"
  depends_on             = [aws_route.private_db_nat]

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
git clone --filter=blob:none --sparse ${var.github_repo_url} /opt/app
cd /opt/app
git sparse-checkout set database
sudo bash database/scripts/mysql_install.sh
bash database/scripts/run-seed.sh
EOF
}

# ── Frontend EC2 ──────────────────────────────────────────────────────────────
# Private IP: 10.1.1.10 | 역할: nginx API Gateway + 정적 파일 서빙
resource "aws_instance" "frontend" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend.id]
  private_ip             = "10.1.1.10"

  tags = { Name = "ThreeTier-Frontend-EC2" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-Frontend-EC2
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail
dnf install -y nginx git
systemctl enable --now nginx
git clone --filter=blob:none --sparse ${var.github_repo_url} /opt/app
cd /opt/app
git sparse-checkout set frontend nginx
cp nginx/nginx.frontend.conf /etc/nginx/nginx.conf
sed -i 's/<EC2-auth Private IP>/10.1.2.10/g'    /etc/nginx/nginx.conf
sed -i 's/<EC2-hotel Private IP>/10.1.2.20/g'   /etc/nginx/nginx.conf
sed -i 's/<EC2-booking Private IP>/10.1.2.30/g' /etc/nginx/nginx.conf
sed -i 's/<EC2-review Private IP>/10.1.2.40/g'  /etc/nginx/nginx.conf
cp -r frontend/public/* /usr/share/nginx/html/
nginx -t && systemctl restart nginx
EOF
}

# ── Auth Service EC2 ──────────────────────────────────────────────────────────
# Private IP: 10.1.2.10 | 포트: 3001 | DB: auth_db
resource "aws_instance" "auth" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  private_ip             = "10.1.2.10"
  depends_on             = [aws_route.private_backend_nat]

  tags = { Name = "ThreeTier-Auth-EC2" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-Auth-EC2
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail
dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
curl -SL https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64 \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
git clone --filter=blob:none --sparse ${var.github_repo_url} /opt/app
cd /opt/app
git sparse-checkout set backend/auth-service
cat > backend/auth-service/.env.mysql-ec2 << 'ENVEOF'
APP_MODE=local
PORT=3001
DB_HOST=10.1.3.10
DB_PORT=3306
DB_USER=root
DB_PASSWORD=P@ssw0rd
DB_NAME=auth_db
JWT_SECRET=${var.jwt_secret}
INTERNAL_SECRET=${var.internal_secret}
CORS_ORIGIN=http://${aws_eip.frontend.public_ip}
ENVEOF
cat > docker-compose.auth.yml << 'DCEOF'
services:
  auth-service:
    build:
      context: ./backend/auth-service
      dockerfile: Dockerfile
    env_file: ./backend/auth-service/.env.mysql-ec2
    ports:
      - '3001:3001'
    restart: on-failure
DCEOF
docker compose -f docker-compose.auth.yml up -d --build
EOF
}

# ── Hotel Service EC2 ─────────────────────────────────────────────────────────
# Private IP: 10.1.2.20 | 포트: 3002 | DB: hotel_db | ElasticMQ: 9324
resource "aws_instance" "hotel" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  private_ip             = "10.1.2.20"
  depends_on             = [aws_route.private_backend_nat]

  tags = { Name = "ThreeTier-Hotel-EC2" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-Hotel-EC2
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail
dd if=/dev/zero of=/swapfile bs=128M count=16
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
curl -SL https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64 \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
git clone --filter=blob:none --sparse ${var.github_repo_url} /opt/app
cd /opt/app
git sparse-checkout set backend/hotel-service elasticmq
cat > backend/hotel-service/.env.mysql-ec2 << 'ENVEOF'
APP_MODE=local
PORT=3002
DB_HOST=10.1.3.10
DB_PORT=3306
DB_USER=root
DB_PASSWORD=P@ssw0rd
DB_NAME=hotel_db
JWT_SECRET=${var.jwt_secret}
INTERNAL_SECRET=${var.internal_secret}
CORS_ORIGIN=http://${aws_eip.frontend.public_ip}
AWS_REGION=ap-northeast-2
DYNAMODB_ENDPOINT=http://localhost:8000
SQS_ENDPOINT=http://elasticmq:9324
SQS_QUEUE_URL=http://elasticmq:9324/000000000000/rating-queue
BOOKING_SERVICE_URL=http://10.1.2.30:3003
REVIEW_SERVICE_URL=http://10.1.2.40:3004
ENVEOF
cat > docker-compose.hotel.yml << 'DCEOF'
services:
  elasticmq:
    image: softwaremill/elasticmq-native:latest
    ports:
      - '9324:9324'
      - '9325:9325'
    volumes:
      - ./elasticmq/elasticmq.conf:/opt/elasticmq.conf:ro

  hotel-service:
    build:
      context: ./backend/hotel-service
      dockerfile: Dockerfile
    env_file: ./backend/hotel-service/.env.mysql-ec2
    ports:
      - '3002:3002'
    depends_on:
      - elasticmq
    restart: on-failure
DCEOF
docker compose -f docker-compose.hotel.yml up -d --build
EOF
}

# ── Booking Service EC2 ───────────────────────────────────────────────────────
# Private IP: 10.1.2.30 | 포트: 3003 | DB: booking_db
resource "aws_instance" "booking" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  private_ip             = "10.1.2.30"
  depends_on             = [aws_route.private_backend_nat]

  tags = { Name = "ThreeTier-Booking-EC2" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-Booking-EC2
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail
dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
curl -SL https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64 \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
git clone --filter=blob:none --sparse ${var.github_repo_url} /opt/app
cd /opt/app
git sparse-checkout set backend/booking-service
cat > backend/booking-service/.env.mysql-ec2 << 'ENVEOF'
APP_MODE=local
PORT=3003
DB_HOST=10.1.3.10
DB_PORT=3306
DB_USER=root
DB_PASSWORD=P@ssw0rd
DB_NAME=booking_db
JWT_SECRET=${var.jwt_secret}
INTERNAL_SECRET=${var.internal_secret}
HOTEL_SERVICE_URL=http://10.1.2.20:3002
CORS_ORIGIN=http://${aws_eip.frontend.public_ip}
AWS_REGION=ap-northeast-2
SQS_ENDPOINT=http://10.1.2.20:9324
SQS_QUEUE_URL=http://10.1.2.20:9324/000000000000/booking-queue
ENVEOF
cat > docker-compose.booking.yml << 'DCEOF'
services:
  booking-service:
    build:
      context: ./backend/booking-service
      dockerfile: Dockerfile
    env_file: ./backend/booking-service/.env.mysql-ec2
    ports:
      - '3003:3003'
    restart: on-failure
DCEOF
docker compose -f docker-compose.booking.yml up -d --build
EOF
}

# ── Review Service EC2 ────────────────────────────────────────────────────────
# Private IP: 10.1.2.40 | 포트: 3004 | DB: review_db
resource "aws_instance" "review" {
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_backend.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  private_ip             = "10.1.2.40"
  depends_on             = [aws_route.private_backend_nat]

  tags = { Name = "ThreeTier-Review-EC2" }

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-Review-EC2
cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail
dnf install -y docker git
systemctl enable --now docker
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
curl -SL https://github.com/docker/buildx/releases/download/v0.19.3/buildx-v0.19.3.linux-amd64 \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
git clone --filter=blob:none --sparse ${var.github_repo_url} /opt/app
cd /opt/app
git sparse-checkout set backend/review-service
cat > backend/review-service/.env.mysql-ec2 << 'ENVEOF'
APP_MODE=local
PORT=3004
DB_HOST=10.1.3.10
DB_PORT=3306
DB_USER=root
DB_PASSWORD=P@ssw0rd
DB_NAME=review_db
JWT_SECRET=${var.jwt_secret}
INTERNAL_SECRET=${var.internal_secret}
BOOKING_SERVICE_URL=http://10.1.2.30:3003
HOTEL_SERVICE_URL=http://10.1.2.20:3002
SQS_ENDPOINT=http://10.1.2.20:9324
SQS_QUEUE_URL=http://10.1.2.20:9324/000000000000/rating-queue
CORS_ORIGIN=http://${aws_eip.frontend.public_ip}
AWS_REGION=ap-northeast-2
ENVEOF
cat > docker-compose.review.yml << 'DCEOF'
services:
  review-service:
    build:
      context: ./backend/review-service
      dockerfile: Dockerfile
    env_file: ./backend/review-service/.env.mysql-ec2
    ports:
      - '3004:3004'
    restart: on-failure
DCEOF
docker compose -f docker-compose.review.yml up -d --build
EOF
}
