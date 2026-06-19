import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { BlobServiceClient } from '@azure/storage-blob';

const s3 = new S3Client({ region: process.env.AWS_REGION || 'ap-northeast-2' });
const secretsManager = new SecretsManagerClient({ region: process.env.AWS_REGION || 'ap-northeast-2' });

const CONNECTION_STRING_SECRET_ARN = process.env.AZURE_BLOB_CONNECTION_STRING_SECRET_ARN;

// Lambda 컨테이너 재사용 시 매번 Secrets Manager를 호출하지 않도록 캐싱
let blobServiceClientPromise;
async function getBlobServiceClient() {
  if (!blobServiceClientPromise) {
    blobServiceClientPromise = secretsManager
      .send(new GetSecretValueCommand({ SecretId: CONNECTION_STRING_SECRET_ARN }))
      .then(({ SecretString }) => BlobServiceClient.fromConnectionString(SecretString));
  }
  return blobServiceClientPromise;
}

// S3 key → Azure Blob (container, blob path) 매핑
// hotels/original/hotel-1/photo.jpg → container "hotels", blob "original/hotel-1/photo.jpg"
// uploads/inquiry-1/file.pdf        → container "uploads", blob "inquiry-1/file.pdf"
function mapToBlob(key) {
  if (key.startsWith('hotels/')) {
    return { container: 'hotels', blobName: key.slice('hotels/'.length) };
  }
  if (key.startsWith('uploads/')) {
    return { container: 'uploads', blobName: key.slice('uploads/'.length) };
  }
  return null;
}

export const handler = async (event) => {
  const blobServiceClient = await getBlobServiceClient();

  for (const record of event.Records) {
    // ex) "threetier-uploads"
    const bucket = record.s3.bucket.name;
    
    // S3 key는 URL 인코딩되어 있음 (공백 → + → %20 등)
    // ex) "hotels/original/hotel-1/photo.jpg"
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    
    // ex) { container: "hotels", blobName: "original/hotel-1/photo.jpg" }
    const mapped = mapToBlob(key);
    if (!mapped) {
      // hotels/, uploads/ 외 경로는 skip
      // ex) "database/mysql_install.sh" → skip
      console.log(`Skip — no container mapping: ${key}`);
      continue;
    }

    // container → "hotels" / blobName → "original/hotel-1/photo.jpg"
    const { container, blobName } = mapped;

    // Azure Blob의 "hotels" 컨테이너 접근
    const containerClient = blobServiceClient.getContainerClient(container);

    // Azure Blob의 "hotels/original/hotel-1/photo.jpg" 파일 지정
    const blockBlobClient = containerClient.getBlockBlobClient(blobName);

    if (record.eventName.startsWith('ObjectRemoved')) {
      // S3에서 파일 삭제 이벤트 → Blob에서도 동일 파일 삭제
      // ex) S3 hotels/original/hotel-1/photo.jpg 삭제 → Blob hotels/original/hotel-1/photo.jpg 삭제
      console.log(`Deleting: s3://${bucket}/${key} → blob ${container}/${blobName}`);
      await blockBlobClient.deleteIfExists();
      continue;
    }

    // S3 파일 생성/수정 이벤트 → Blob에 업로드
    // ex) s3://threetier-uploads/hotels/original/hotel-1/photo.jpg → blob hotels/original/hotel-1/photo.jpg
    console.log(`Syncing: s3://${bucket}/${key} → blob ${container}/${blobName}`);

    const { Body, ContentType } = await s3.send(
      new GetObjectCommand({ Bucket: bucket, Key: key })
    );
    const chunks = [];
    for await (const chunk of Body) chunks.push(chunk);
    const buffer = Buffer.concat(chunks);

    await blockBlobClient.upload(buffer, buffer.length, {
      blobHTTPHeaders: { blobContentType: ContentType },
    });

    console.log(`Synced: ${container}/${blobName} (${buffer.length} bytes)`);
  }
};
