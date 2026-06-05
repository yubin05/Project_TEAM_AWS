#!/bin/bash
set -euxo pipefail

# AL2023 기본 repo 사용 (외부 인터넷 불필요 — S3 VPC 엔드포인트로 패키지 수신)
dnf install -y mariadb1011-server

cat <<EOT > /etc/my.cnf
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mariadb/mariadb.log
pid-file=/var/run/mariadb/mariadb.pid
collation-server=utf8mb4_general_ci
character-set-server=utf8mb4

[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4
EOT

systemctl enable --now mariadb

DB_PASSWORD="${DB_PASSWORD:-P@ssw0rd}"

# MariaDB 초기 root는 비밀번호 없이 소켓 인증으로 접속
mysql -u root <<EOT
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS 'user1'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'user1'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOT
