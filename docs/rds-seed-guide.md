# RDS 데이터 수동 삽입 가이드

## 접속 방법

AWS 콘솔 → EC2 → ThreeTier-MySQL-EC2 → 연결 → Session Manager

## 1. RDS DB 생성

```bash
export rds_endpoint="<Your RDS Endpoint>"

mysql -h ${rds_endpoint} -u admin -pChange-me-db-password1!
```

```sql
CREATE DATABASE IF NOT EXISTS auth_db;
CREATE DATABASE IF NOT EXISTS hotel_db;
CREATE DATABASE IF NOT EXISTS booking_db;
CREATE DATABASE IF NOT EXISTS review_db;
```

> RDS 엔드포인트 확인: `terraform output rds_endpoint`

## 2. 시드 데이터 삽입

```bash
cd /opt/app
MYSQL_HOST=${rds_endpoint} MYSQL_USER=admin MYSQL_PASSWORD=Change-me-db-password1! bash database/scripts/run-seed.sh
```

실행 후 테스트 계정:
- `user@travel.com` / `password123`
- `host@travel.com` / `password123`
- `admin@travel.com` / `password123`

## 주의사항

DMS 마이그레이션 실행 전 RDS 데이터가 있으면 중복 충돌이 발생합니다.
DMS 태스크 생성 시 `Target table preparation mode = TRUNCATE_BEFORE_LOAD` 설정 필요.
