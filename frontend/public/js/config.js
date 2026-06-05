// ===== API 설정 =====
// Amplify 배포: amplify.yml 빌드 스펙에서 환경변수로 자동 교체됨
// 로컬/EC2: 접속한 호스트 기준으로 백엔드 자동 연결
const API_BASE = window.__API_BASE__ || `http://${window.location.hostname}`;
const SUPPORT_BASE = window.__SUPPORT_BASE__ || API_BASE;

// Azure Maps 키 (Azure Portal에서 도메인 제한 설정 필요)
const AZURE_MAPS_KEY = window.__AZURE_MAPS_KEY__ || '';
