import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, GetCommand, PutCommand } from '@aws-sdk/lib-dynamodb';
import { config, isLocal } from '../config';

// 로컬: endpoint 지정 + 더미 자격증명 / AWS: IAM Role 자동 사용
const client = new DynamoDBClient({
  region: config.dynamo.region,
  ...(config.dynamo.endpoint && { endpoint: config.dynamo.endpoint }),
  ...(isLocal && {
    credentials: { accessKeyId: 'local', secretAccessKey: 'local' },
  }),
});

export const dynamoDb = DynamoDBDocumentClient.from(client);

// ─── 번역 캐시 ────────────────────────────────────────────────────────────────

export async function getCachedTranslation(
  text: string,
  targetLang: string
): Promise<string | null> {
  try {
    const key = `translate#ko#${targetLang}#${Buffer.from(text).toString('base64').slice(0, 64)}`;
    const { Item } = await dynamoDb.send(
      new GetCommand({ TableName: config.dynamo.tableName, Key: { pk: key } })
    );
    return Item?.value ?? null;
  } catch {
    return null;
  }
}

export async function setCachedTranslation(
  text: string,
  targetLang: string,
  translated: string
): Promise<void> {
  try {
    const key = `translate#ko#${targetLang}#${Buffer.from(text).toString('base64').slice(0, 64)}`;
    const ttl = Math.floor(Date.now() / 1000) + 7 * 24 * 3600; // 7일 TTL
    await dynamoDb.send(
      new PutCommand({
        TableName: config.dynamo.tableName,
        Item: { pk: key, value: translated, ttl },
      })
    );
  } catch {
    // 캐시 실패는 무시
  }
}
