export const config = {
  mode:     process.env.APP_MODE || 'local',
  port:     Number(process.env.PORT) || 3002,
  db: {
    host:     process.env.DB_HOST     || 'localhost',
    port:     Number(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER     || 'root',
    password: process.env.DB_PASSWORD || 'localpassword',
    name:     process.env.DB_NAME     || 'hotel_db',
  },
  cognito: {
    userPoolId: process.env.COGNITO_USER_POOL_ID || '',
    clientId:   process.env.COGNITO_CLIENT_ID   || '',
    region:     process.env.AWS_REGION          || 'ap-northeast-2',
  },
  dynamo: {
    endpoint:  process.env.DYNAMO_ENDPOINT,
    region:    process.env.AWS_REGION   || 'ap-northeast-2',
    tableName: process.env.DYNAMO_TABLE || 'TravelBookingCache',
  },
  azure: {
    translatorKey:      process.env.AZURE_TRANSLATOR_KEY      || '',
    translatorEndpoint: process.env.AZURE_TRANSLATOR_ENDPOINT || 'https://api.cognitive.microsofttranslator.com',
    translatorRegion:   process.env.AZURE_TRANSLATOR_REGION   || 'koreacentral',
    blob: {
      accountName: process.env.AZURE_STORAGE_ACCOUNT || '',
      accountKey:  process.env.AZURE_STORAGE_KEY     || '',
      containers: {
        hotels:  'hotels',
        uploads: 'uploads',
      },
    },
  },
  s3: {
    region:       process.env.AWS_REGION              || 'ap-northeast-2',
    imagesBucket: process.env.S3_IMAGES_BUCKET         || '',
    sourceBucket: process.env.S3_SOURCE_BUCKET        || '',
    outputBucket: process.env.S3_OUTPUT_BUCKET        || '',
    cdnDomain:    process.env.S3_CLOUDFRONT_DOMAIN    || '',
    lambdaSecret: process.env.LAMBDA_CALLBACK_SECRET  || 'local-secret',
  },
  mediaConvert: {
    endpoint: process.env.MEDIACONVERT_ENDPOINT || '',
    roleArn:  process.env.MEDIACONVERT_ROLE_ARN || '',
  },
  internal: {
    secret:         process.env.INTERNAL_SECRET         || 'local-internal-secret',
    bookingService: process.env.BOOKING_SERVICE_URL     || 'http://booking-service:3003',
    reviewService:  process.env.REVIEW_SERVICE_URL      || 'http://review-service:3004',
  },
  sqs: {
    endpoint: process.env.SQS_ENDPOINT  || 'http://elasticmq:9324',
    queueUrl: process.env.SQS_QUEUE_URL || 'http://elasticmq:9324/000000000000/rating-queue',
    region:   process.env.AWS_REGION    || 'ap-northeast-2',
  },
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
  },
};

