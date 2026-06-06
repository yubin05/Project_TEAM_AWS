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

export const isLocal = config.mode === 'local';
export const isAWS   = config.mode === 'aws';

export async function loadSecrets(): Promise<void> {
  if (isLocal) return;
  const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
  const client = new SecretsManagerClient({ region: config.s3.region });
  const { SecretString } = await client.send(
    new GetSecretValueCommand({ SecretId: 'travel-app/support-service' })
  );
  const values = JSON.parse(SecretString!);
  if (values.DB_PASSWORD)     process.env.DB_PASSWORD     = values.DB_PASSWORD;
  if (values.JWT_SECRET)      process.env.JWT_SECRET      = values.JWT_SECRET;
  if (values.INTERNAL_SECRET) process.env.INTERNAL_SECRET = values.INTERNAL_SECRET;
}
