export const config = {
  mode: process.env.APP_MODE || 'local',       // 'local' | 'aws'
  port: Number(process.env.PORT) || 3000,

  db: {
    host:     process.env.DB_HOST     || 'localhost',
    port:     Number(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER     || 'root',
    password: process.env.DB_PASSWORD || 'localpassword',
    name:     process.env.DB_NAME     || 'travel_booking',
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'local-dev-secret-key-2024',
  },

  cognito: {
    userPoolId: process.env.COGNITO_USER_POOL_ID || '',
    clientId:   process.env.COGNITO_CLIENT_ID   || '',
    region:     process.env.AWS_REGION          || 'ap-northeast-2',
  },

  dynamo: {
    endpoint:  process.env.DYNAMO_ENDPOINT,                       // 로컬: http://dynamodb-local:8000 / AWS: undefined
    region:    process.env.AWS_REGION    || 'ap-northeast-2',
    tableName: process.env.DYNAMO_TABLE  || 'TravelBookingCache',
  },

  translate: {
    region: process.env.AWS_REGION || 'ap-northeast-2',
  },

  cors: {
    origin: process.env.CORS_ORIGIN || '*',
  },

  s3: {
    region:       process.env.AWS_REGION         || 'ap-northeast-2',
    sourceBucket: process.env.S3_SOURCE_BUCKET   || '',   // 원본 MP4 업로드
    outputBucket: process.env.S3_OUTPUT_BUCKET   || '',   // HLS 변환본 저장
    cdnDomain:    process.env.S3_CLOUDFRONT_DOMAIN || '', // CloudFront URL
    lambdaSecret: process.env.LAMBDA_CALLBACK_SECRET || 'local-secret',
  },

  mediaConvert: {
    endpoint: process.env.MEDIACONVERT_ENDPOINT || '',
    roleArn:  process.env.MEDIACONVERT_ROLE_ARN || '',
  },
};

export const isLocal = config.mode === 'local';
export const isAWS   = config.mode === 'aws';
