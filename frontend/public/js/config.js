// ===== API 설정 =====
// 로컬 개발: http://localhost:3000/api
// Amplify 배포: amplify.yml 빌드 스펙에서 환경변수로 자동 교체됨
const API_BASE = window.__API_BASE__ || 'http://localhost:3000/api';
