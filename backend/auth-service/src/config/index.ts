export const config = {
  mode:     process.env.APP_MODE || 'local',
  port:     Number(process.env.PORT) || 3001,
  db: {
    host:     process.env.DB_HOST     || 'localhost',
    port:     Number(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER     || 'root',
    password: process.env.DB_PASSWORD || 'localpassword',
    name:     process.env.DB_NAME     || 'auth_db',
  },
  cognito: {
    userPoolId: process.env.COGNITO_USER_POOL_ID || '',
    clientId:   process.env.COGNITO_CLIENT_ID   || '',
    region:     process.env.AWS_REGION          || 'ap-northeast-2',
  },
  internal: {
    secret: process.env.INTERNAL_SECRET || 'local-internal-secret',
  },
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
  },
};

