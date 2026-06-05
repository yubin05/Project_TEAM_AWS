export const config = {
  mode: process.env.APP_MODE || 'local',
  port: Number(process.env.PORT) || 3005,
  db: {
    host:     process.env.DB_HOST     || 'localhost',
    port:     Number(process.env.DB_PORT) || 3306,
    user:     process.env.DB_USER     || 'root',
    password: process.env.DB_PASSWORD || 'localpassword',
    name:     process.env.DB_NAME     || 'support_db',
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'local-dev-secret-key-2024',
  },
  internal: {
    secret: process.env.INTERNAL_SECRET || 'local-internal-secret',
  },
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
  },
  s3: {
    bucket: process.env.S3_UPLOADS_BUCKET || '',
    region: process.env.AWS_REGION || 'ap-northeast-2',
  },
};

export async function loadSecrets(): Promise<void> {}
