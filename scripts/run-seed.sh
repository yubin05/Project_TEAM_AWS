#!/bin/bash
# ============================================================
# 시드 데이터 삽입 스크립트
# 사용법: bash scripts/run-seed.sh [mysql_root_password]
#
# 전제 조건:
#   1. MySQL이 실행 중일 것 (호스트 직접 설치 또는 Docker)
#   2. 서비스가 최소 1회 기동되어 테이블이 생성된 상태일 것
#      (또는 scripts/init-databases.sql 먼저 실행)
# ============================================================

set -e

MYSQL_PASSWORD="P@ssw0rd"
MYSQL_USER="root"
MYSQL_HOST="127.0.0.1"

# ── 1. bcrypt 해시 생성 ──────────────────────────────────────
echo "🔐 bcrypt 해시 생성 중 (password123)..."

# auth-service node_modules의 bcryptjs 사용
BCRYPT_HASH=$(node -e "
  const b = require('./services/auth-service/node_modules/bcryptjs');
  b.hash('password123', 10).then(h => { process.stdout.write(h); });
")

if [ -z "$BCRYPT_HASH" ]; then
  echo "❌ bcrypt 해시 생성 실패. auth-service node_modules가 설치되어 있는지 확인하세요."
  echo "   cd services/auth-service && npm install"
  exit 1
fi

echo "✅ bcrypt 해시 생성 완료"

# ── 2. SQL에 해시 주입 후 임시 파일 생성 ─────────────────────
TMP_SQL=$(mktemp /tmp/seed_XXXXXX.sql)
sed "s|__BCRYPT_HASH__|${BCRYPT_HASH}|g" "$(dirname "$0")/seed.sql" > "$TMP_SQL"

# ── 3. MySQL 실행 ─────────────────────────────────────────────
echo "🌱 시드 데이터 삽입 중..."

mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -h "$MYSQL_HOST" < "$TMP_SQL"

# ── 4. 임시 파일 삭제 ─────────────────────────────────────────
rm -f "$TMP_SQL"

echo ""
echo "✅ 시드 데이터 삽입 완료!"
echo ""
echo "   테스트 계정 (비밀번호: password123)"
echo "   ├── admin@travel.com  (관리자)"
echo "   ├── host@travel.com   (호스트)"
echo "   ├── host2@travel.com  (호스트)"
echo "   ├── user@travel.com   (사용자)"
echo "   ├── user2@travel.com  (사용자)"
echo "   └── user3@travel.com  (사용자)"
