import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';
import { BlobServiceClient } from '@azure/storage-blob';
import sharp from 'sharp';

const s3 = new S3Client({ region: process.env.AWS_REGION || 'ap-northeast-2' });
const secretsManager = new SecretsManagerClient({ region: process.env.AWS_REGION || 'ap-northeast-2' });

const THUMBNAIL_WIDTH  = parseInt(process.env.THUMBNAIL_WIDTH  || '400');
const THUMBNAIL_HEIGHT = parseInt(process.env.THUMBNAIL_HEIGHT || '300');
const ORIGINAL_PREFIX  = process.env.ORIGINAL_PREFIX  || 'hotels/original/';
const THUMBNAIL_PREFIX = process.env.THUMBNAIL_PREFIX || 'hotels/thumbnails/';

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

export const handler = async (event) => {
  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    // S3 key는 URL 인코딩되어 있음 (공백 → + → %20 등)
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    // 무한루프 방지: 썸네일 prefix로 들어온 이벤트는 무시
    if (!key.startsWith(ORIGINAL_PREFIX)) {
      console.log(`Skip — not an original image: ${key}`);
      return;
    }

    // hotels/original/hotel-1/photo.jpg  →  hotels/thumbnails/hotel-1/photo.jpg
    const thumbnailKey = key.replace(ORIGINAL_PREFIX, THUMBNAIL_PREFIX);

    console.log(`Processing: s3://${bucket}/${key} → ${thumbnailKey}`);

    // 원본 이미지 다운로드
    const { Body, ContentType } = await s3.send(
      new GetObjectCommand({ Bucket: bucket, Key: key })
    );
    const chunks = [];
    for await (const chunk of Body) chunks.push(chunk);
    const originalBuffer = Buffer.concat(chunks);

    // Sharp 리사이즈 (fit: 'cover' = 비율 유지하며 크롭, 여백 없음)
    const resizedBuffer = await sharp(originalBuffer)
      .resize(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, { fit: 'cover', position: 'centre' })
      .jpeg({ quality: 85 })
      .toBuffer();

    // 썸네일 S3 저장
    await s3.send(new PutObjectCommand({
      Bucket: bucket,
      Key: thumbnailKey,
      Body: resizedBuffer,
      ContentType: 'image/jpeg',
      Metadata: {
        'original-key': key,
        'resized-width': String(THUMBNAIL_WIDTH),
        'resized-height': String(THUMBNAIL_HEIGHT),
      },
    }));

    console.log(`Thumbnail saved: s3://${bucket}/${thumbnailKey} (${resizedBuffer.length} bytes)`);

    // 원본을 Azure Blob hotels/original/ 에도 동기화
    // (s3-blob-sync는 image-resize와의 충돌(ambiguous configuration)을 피하기 위해
    //  hotels/original/ ObjectCreated를 구독하지 않으므로, 여기서 함께 업로드)
    const blobServiceClient = await getBlobServiceClient();
    const blobName = key.replace(ORIGINAL_PREFIX, 'original/');
    const blockBlobClient = blobServiceClient.getContainerClient('hotels').getBlockBlobClient(blobName);
    await blockBlobClient.upload(originalBuffer, originalBuffer.length, {
      blobHTTPHeaders: { blobContentType: ContentType },
    });

    console.log(`Original synced to Azure Blob: hotels/${blobName} (${originalBuffer.length} bytes)`);
  }
};
