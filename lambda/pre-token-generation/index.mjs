// Cognito Access Token에는 커스텀 속성(custom:*)이 기본적으로 포함되지 않으므로,
// 토큰 발급 시점에 사용자의 custom:role 값을 Access Token 클레임으로 복사해 넣는다.
// (백엔드 미들웨어가 payload['custom:role']을 읽어 권한을 판별하기 때문에 필요함)
export const handler = async (event) => {
  const role = event.request.userAttributes['custom:role'] ?? 'user';

  event.response = {
    claimsAndScopeOverrideDetails: {
      accessTokenGeneration: {
        claimsToAddOrOverride: {
          'custom:role': role,
        },
      },
    },
  };

  return event;
};
