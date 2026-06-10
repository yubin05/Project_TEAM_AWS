locals {
  ami_id = data.aws_ssm_parameter.al2023_ami.value
}


# ── CGW EC2 (Libreswan) ───────────────────────────────────────────────────────
# IDC VPC Public Subnet에 위치. EIP를 통해 AWS VGW와 IPSec 터널 수립.
# source_dest_check=false: 라우터 역할 수행 (IDC Private ↔ Main VPC 패킷 포워딩)
resource "aws_instance" "cgw" {
  count                  = var.enable_migration ? 1 : 0
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.idc_public[0].id
  vpc_security_group_ids = [aws_security_group.cgw[0].id]
  source_dest_check      = false
  tags                   = { Name = "ThreeTier-CGW-EC2" }

  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-vpn.conf
echo "net.ipv4.conf.all.forwarding = 1" >> /etc/sysctl.d/99-vpn.conf
sysctl -p /etc/sysctl.d/99-vpn.conf

dnf install -y libreswan iptables

CGW_IP="${aws_eip.cgw[0].public_ip}"
VGW_IP="${aws_vpn_connection.main[0].tunnel1_address}"
PSK="${aws_vpn_connection.main[0].tunnel1_preshared_key}"

cat > /etc/ipsec.d/tunnel1.conf << IPSEC_CONF
conn tunnel1
  auto=start
  left=%defaultroute
  leftid=$CGW_IP
  right=$VGW_IP
  type=tunnel
  authby=secret
  ikev2=no
  ike=aes128-sha1-modp2048
  ikelifetime=28800s
  phase2=esp
  phase2alg=aes128-sha1-modp2048
  salifetime=3600s
  keyingtries=%forever
  leftsubnet=10.0.0.0/16
  rightsubnet=10.1.0.0/16
  dpdaction=restart
  dpddelay=10
  dpdtimeout=30
IPSEC_CONF

cat >> /etc/ipsec.secrets << IPSEC_SECRETS
$CGW_IP $VGW_IP : PSK "$PSK"
IPSEC_SECRETS

# VPN 터널 대상(Main VPC)로 가는 트래픽은 MASQUERADE 제외 (IPsec 셀렉터 유지 위해 출발지 IP 보존)
iptables -t nat -A POSTROUTING -s 10.0.0.0/16 -d 10.1.0.0/16 -j ACCEPT
# IDC VPC 내부 트래픽을 인터넷으로 MASQUERADE (MySQL EC2 → SSM 등 outbound)
iptables -t nat -A POSTROUTING -s 10.0.0.0/16 ! -d 10.0.0.0/16 -j MASQUERADE
iptables -A FORWARD -j ACCEPT

systemctl enable ipsec
systemctl start ipsec
EOF

  depends_on = [aws_vpn_connection.main]
}

# ── MySQL EC2 ─────────────────────────────────────────────────────────────────
# IDC VPC Private Subnet으로 이동 — 온프레미스 DB 시뮬레이션
# enable_migration = false 로 변경 후 apply 하면 자동 삭제
resource "aws_instance" "mysql" {
  count = var.enable_migration ? 1 : 0
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.idc_private[0].id
  vpc_security_group_ids = [aws_security_group.mysql[0].id]
  private_ip             = "10.0.2.10"
  tags                   = { Name = "ThreeTier-MySQL-EC2" }

  depends_on = [aws_eip_association.cgw]

  user_data = <<-EOF
#!/bin/bash
hostnamectl --static set-hostname ThreeTier-MySQL-EC2

cat <<EOT > /etc/profile.d/prompt.sh
export PS1="[\[\e[1;31m\]\u\[\e[m\]@\[\e[1;32m\]\h\[\e[m\]: \[\e[1;36m\]\w\[\e[m\]]#"
EOT
source /etc/profile
set -euxo pipefail

# CGW MASQUERADE 준비 대기 후 S3 다운로드
for i in $(seq 1 18); do
  aws s3 cp s3://${aws_s3_bucket.uploads.bucket}/database/mysql_install.sh /tmp/mysql_install.sh 2>/dev/null && break
  echo "[$i/18] CGW MASQUERADE 대기 중... 10초 후 재시도"
  sleep 10
done

aws s3 cp s3://${aws_s3_bucket.uploads.bucket}/database/run-seed.sh /tmp/run-seed.sh
aws s3 cp s3://${aws_s3_bucket.uploads.bucket}/database/seed.sql /tmp/seed.sql
chmod +x /tmp/mysql_install.sh /tmp/run-seed.sh

DB_PASSWORD="${var.db_password}" bash /tmp/mysql_install.sh
MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD="${var.db_password}" bash /tmp/run-seed.sh
touch /tmp/mysql_ready
EOF
}

# ── SSM 터널 EC2 ──────────────────────────────────────────────────────────────
# OpenSearch가 VPC private subnet에 배포되면 퍼블릭 엔드포인트가 없으므로
# 로컬 PC → SSM 포트 포워딩 → 이 EC2 경유 → OpenSearch Dashboards 접근
# 키 페어 없음 / 인바운드 포트 전체 차단 / SSM VPC 엔드포인트 경유로 연결
# enable_opensearch_tunnel = true 일 때만 생성 (평소 false → 비용 절감)
resource "aws_instance" "ssm_tunnel" {
  count                  = var.enable_opensearch_tunnel ? 1 : 0
  ami                    = local.ami_id
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  subnet_id              = aws_subnet.private_backend.id
  vpc_security_group_ids = [aws_security_group.ssm_tunnel.id]
  tags                   = { Name = "ThreeTier-SSMTunnel-EC2", Project = "threetier" }
}

output "ssm_tunnel_instance_id" {
  value       = var.enable_opensearch_tunnel ? aws_instance.ssm_tunnel[0].id : "enable_opensearch_tunnel = true 로 설정 후 terraform apply 필요"
  description = "SSM 포트 포워딩 명령에 사용할 EC2 인스턴스 ID"
}
