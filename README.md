# ✈️ 야놀자 - 여행 및 숙박 예약 앱

Node.js + TypeScript로 구현한 야놀자 스타일의 여행 및 숙박 예약 플랫폼입니다.

## 🚀 빠른 시작

```bash
# 1. 백엔드 의존성 설치
cd backend && npm install

# 2. 시드 데이터 입력
npm run seed

# 3. TypeScript 빌드
npm run build

# 4. 서버 실행
npm start
# 또는 개발 모드 (핫리로드)
npm run dev
```

서버가 실행되면 브라우저에서 http://localhost:3000 을 열어주세요.

## 📧 테스트 계정

| 역할 | 이메일 | 비밀번호 |
|------|--------|---------|
| 관리자 | admin@travel.com | password123 |
| 호스트 | host@travel.com | password123 |
| 일반 | user@travel.com | password123 |

## 🏗️ 프로젝트 구조

```
Project_TEAM_AWS/
├── backend/
│   ├── src/
│   │   ├── app.ts              # 메인 서버
│   │   ├── controllers/
│   │   │   ├── authController.ts
│   │   │   ├── hotelController.ts
│   │   │   ├── bookingController.ts
│   │   │   └── reviewController.ts
│   │   ├── middleware/
│   │   │   └── auth.ts         # JWT 인증 미들웨어
│   │   ├── models/
│   │   │   └── database.ts     # SQLite DB 초기화
│   │   ├── routes/
│   │   │   └── index.ts        # API 라우트
│   │   ├── types/
│   │   │   └── index.ts        # TypeScript 타입 정의
│   │   └── seed.ts             # 시드 데이터
│   ├── data/                   # SQLite DB 파일
│   ├── dist/                   # 빌드 결과물
│   ├── package.json
│   └── tsconfig.json
└── frontend/
    └── public/
        ├── index.html          # 메인 HTML
        ├── css/style.css       # 스타일시트
        └── js/app.js           # 프론트엔드 로직
```

## 🔌 API 엔드포인트

### 인증
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | /api/auth/register | 회원가입 |
| POST | /api/auth/login | 로그인 |
| GET | /api/auth/profile | 프로필 조회 |
| PUT | /api/auth/profile | 프로필 수정 |
| PUT | /api/auth/password | 비밀번호 변경 |

### 숙소
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | /api/hotels/featured | 인기 숙소 |
| GET | /api/hotels/search | 숙소 검색 |
| GET | /api/hotels/:id | 숙소 상세 |
| POST | /api/hotels | 숙소 등록 (호스트) |
| GET | /api/hotels/:id/rooms/:roomId | 객실 상세 |
| GET | /api/hotels/:id/rooms/:roomId/availability | 가용 확인 |

### 예약
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | /api/bookings | 예약 생성 |
| GET | /api/bookings | 내 예약 목록 |
| GET | /api/bookings/:id | 예약 상세 |
| DELETE | /api/bookings/:id | 예약 취소 |

### 리뷰 / 위시리스트
| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | /api/hotels/:id/reviews | 리뷰 목록 |
| POST | /api/reviews | 리뷰 작성 |
| DELETE | /api/reviews/:id | 리뷰 삭제 |
| POST | /api/wishlist/:hotelId | 위시리스트 토글 |
| GET | /api/wishlist | 위시리스트 조회 |

## 🛠️ 기술 스택

**백엔드**
- Node.js + TypeScript
- Express.js
- better-sqlite3 (SQLite)
- jsonwebtoken (JWT 인증)
- bcryptjs (비밀번호 암호화)

**프론트엔드**
- Vanilla HTML5 / CSS3 / JavaScript (ES6+)
- 모바일 반응형 디자인

## ✨ 주요 기능

- 🔐 JWT 기반 회원 인증 (일반/호스트/관리자)
- 🏨 숙소 검색 (지역, 날짜, 인원, 가격 필터)
- 📅 실시간 가용성 확인 및 예약
- 📋 예약 관리 (확인/취소)
- ⭐ 리뷰 작성 및 평점
- 🤍 위시리스트
- 📱 반응형 UI