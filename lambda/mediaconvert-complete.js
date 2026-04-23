/**
 * Lambda: mediaconvert-complete
 *
 * 트리거: EventBridge Rule
 *   source:      ["aws.mediaconvert"]
 *   detail-type: ["MediaConvert Job State Change"]
 *   detail.status: ["COMPLETE"]
 *
 * 역할: MediaConvert 완료 후 백엔드 API를 호출해 video_url 업데이트
 *
 * 필요 환경변수:
 *   BACKEND_API_URL         예) https://api.yourdomain.com/api
 *   LAMBDA_CALLBACK_SECRET  백엔드와 공유하는 시크릿 토큰
 *   S3_CLOUDFRONT_DOMAIN    예) https://xxxx.cloudfront.net
 *
 * 필요 IAM 권한 (Lambda 실행 역할):
 *   없음 (HTTP 호출만 함)
 */

const https = require('https');
const http  = require('http');
const url   = require('url');

const BACKEND_URL = process.env.BACKEND_API_URL;
const SECRET      = process.env.LAMBDA_CALLBACK_SECRET;
const CDN_DOMAIN  = process.env.S3_CLOUDFRONT_DOMAIN;

exports.handler = async (event) => {
  console.log('MediaConvert complete event:', JSON.stringify(event, null, 2));

  const detail   = event.detail;
  const status   = detail.status;
  const hotelId  = detail.userMetadata?.hotelId;

  if (status !== 'COMPLETE') {
    console.log(`Job status: ${status} — skipping`);
    return;
  }
  if (!hotelId) {
    console.error('hotelId not found in userMetadata');
    return;
  }

  // HLS 마스터 플레이리스트 URL 구성
  // MediaConvert 출력: output-videos/{hotelId}/index.m3u8
  const videoUrl = `${CDN_DOMAIN}/output-videos/${hotelId}/index.m3u8`;

  const body = JSON.stringify({ video_url: videoUrl, secret: SECRET });
  const apiUrl = `${BACKEND_URL}/hotels/${hotelId}/video-url`;

  try {
    await httpPost(apiUrl, body);
    console.log(`video_url updated for hotel ${hotelId}: ${videoUrl}`);
  } catch (err) {
    console.error('Backend callback failed:', err);
    throw err;
  }
};

function httpPost(apiUrl, body) {
  return new Promise((resolve, reject) => {
    const parsed  = url.parse(apiUrl);
    const lib     = parsed.protocol === 'https:' ? https : http;
    const options = {
      hostname: parsed.hostname,
      port:     parsed.port,
      path:     parsed.path,
      method:   'POST',
      headers:  {
        'Content-Type':   'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    };

    const req = lib.request(options, (res) => {
      let data = '';
      res.on('data', chunk => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    req.write(body);
    req.end();
  });
}
