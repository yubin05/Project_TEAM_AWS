#!/bin/bash
# ================================================================
# Failback: AWS 복구 시 Azure Active 기간에 Azure MySQL에 새로 쌓인
# 데이터(신규 row)를 Aurora MySQL로 가져온다.
#
# CDC(aurora_to_azure)는 Aurora -> Azure 단방향이라 DR 기간 동안
# Azure에서 직접 생성된 데이터는 Aurora에 반영되지 않는다.
# 본 스크립트는 각 테이블의 created_at >= DR_START 인 row만
# Azure MySQL에서 덤프하여 Aurora에 INSERT IGNORE로 반영한다.
#
# 실행 위치: Main VPC private_backend 서브넷의 EC2 (Aurora 3306,
#            Azure MySQL 10.2.3.4:3306 라우트/SG 모두 허용된 곳)
#            mysql-client 필요 (sudo dnf install -y mysql)
#
# 한계: DR 기간 중 기존 row의 UPDATE(예: 리뷰로 인한 hotels.rating
#       갱신)는 created_at 기준이라 반영되지 않음 — 신규 row만 대상.
#
# 사용:
#   AURORA_HOST=<rds_endpoint> DB_PASSWORD=<aurora pw> \
#   AZURE_MYSQL_HOST=10.2.3.4 AZURE_MYSQL_USER=<user> AZURE_MYSQL_PASSWORD=<pw> \
#   ./failback-db-to-aurora.sh "2026-06-13 10:00:00"
# ================================================================
set -euo pipefail

DR_START="${1:?사용법: $0 \"YYYY-MM-DD HH:MM:SS\" (AWS 장애 시작 시각)}"

: "${AURORA_HOST:?AURORA_HOST 환경변수 필요}"
: "${DB_PASSWORD:?DB_PASSWORD 환경변수 필요}"
: "${AZURE_MYSQL_HOST:?AZURE_MYSQL_HOST 환경변수 필요}"
: "${AZURE_MYSQL_USER:?AZURE_MYSQL_USER 환경변수 필요}"
: "${AZURE_MYSQL_PASSWORD:?AZURE_MYSQL_PASSWORD 환경변수 필요}"

AURORA_USER="admin"

# schema:table 목록 (모두 id VARCHAR(36) PK + created_at 보유)
TABLES=(
  "auth_db:users"
  "hotel_db:hotels"
  "hotel_db:rooms"
  "hotel_db:wishlists"
  "booking_db:bookings"
  "review_db:reviews"
  "support_db:inquiries"
  "support_db:notices"
)

for entry in "${TABLES[@]}"; do
  schema="${entry%%:*}"
  table="${entry##*:}"

  echo "==> ${schema}.${table} (created_at >= '${DR_START}') Azure -> Aurora"

  mysqldump \
    -h "$AZURE_MYSQL_HOST" -u "$AZURE_MYSQL_USER" -p"$AZURE_MYSQL_PASSWORD" \
    --no-create-info --skip-add-locks --skip-disable-keys --insert-ignore \
    --where="created_at >= '${DR_START}'" \
    "$schema" "$table" \
  | mysql -h "$AURORA_HOST" -u "$AURORA_USER" -p"$DB_PASSWORD" "$schema"
done

echo "==> Failback sync 완료"
