// ===== API 설정 =====
// Amplify 배포: amplify.yml 빌드 스펙에서 환경변수로 자동 교체됨
// 로컬/EC2: 접속한 호스트 기준으로 백엔드 자동 연결
const API_BASE = window.__API_BASE__ || 'https://threetier-dr-apim-v2.azure-api.net';
const SUPPORT_BASE = window.__SUPPORT_BASE__ || 'https://support-service.mangoriver-6a266378.koreacentral.azurecontainerapps.io';

// Azure Maps 키 (Azure Portal에서 도메인 제한 설정 필요)
const AZURE_MAPS_KEY = window.__AZURE_MAPS_KEY__ || '';

// 현재 배포 환경 표시 (Amplify 빌드 시 amplify.yml에서 'AWS'로 덮어씀)
const CLOUD_PROVIDER = window.__CLOUD_PROVIDER__ || 'Azure';

// v2

// v2
