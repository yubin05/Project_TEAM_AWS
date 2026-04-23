// ===== API 설정 =====
// Amplify 배포: amplify.yml 빌드 스펙에서 환경변수로 자동 교체됨
// 로컬/EC2: 접속한 호스트 기준으로 백엔드 자동 연결
const API_BASE = window.__API_BASE__ || `http://${window.location.hostname}:3000/api`;
