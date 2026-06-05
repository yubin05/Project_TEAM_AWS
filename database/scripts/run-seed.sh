#!/bin/bash
# ============================================================
# seed 실행 스크립트
# 사용법:
#   Aurora 직접 주입:
#     MYSQL_HOST=<Aurora엔드포인트> MYSQL_PASSWORD=<비밀번호> bash database/scripts/run-seed.sh
#   MySQL/MariaDB EC2 로컬:
#     MYSQL_HOST=127.0.0.1 MYSQL_USER=root MYSQL_PASSWORD=<비밀번호> bash /tmp/run-seed.sh
# ============================================================

set -e

MYSQL_HOST="${MYSQL_HOST:?MYSQL_HOST 환경변수를 지정해주세요 (Aurora 엔드포인트 또는 127.0.0.1)}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-admin}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:?MYSQL_PASSWORD 환경변수를 지정해주세요}"
SEED_PASSWORD="${SEED_PASSWORD:-password123}"

# python3-bcrypt 설치 (AL2023 repo — 외부 인터넷 불필요)
if ! python3 -c "import bcrypt" 2>/dev/null; then
  echo "▶ python3-bcrypt 설치 중..."
  sudo dnf install -y python3-bcrypt 2>/dev/null || sudo pip3 install bcrypt
fi

echo "▶ bcrypt 해시 생성 중..."
BCRYPT_HASH=$(python3 -c "
import bcrypt
h = bcrypt.hashpw('${SEED_PASSWORD}'.encode(), bcrypt.gensalt(10)).decode()
print(h)
")
echo "✅ 해시 생성 완료"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "▶ seed.sql 실행 중... (host: $MYSQL_HOST)"
sed "s/__BCRYPT_HASH__/${BCRYPT_HASH//\//\\/}/g" "$SCRIPT_DIR/seed.sql" | \
  mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD"

echo "✅ 시드 데이터 삽입 완료"
