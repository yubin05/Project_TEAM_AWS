import { Request, Response } from 'express';
import { config } from '../config';
import logger from '../utils/logger';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import {
  StorageSharedKeyCredential,
  generateBlobSASQueryParameters,
  BlobSASPermissions,
} from '@azure/storage-blob';

async function getAzureImageUploadUrl(id: string, filename: string, contentType: string) {
  const { accountName, accountKey, containers } = config.azure.blob;
  const blobName = `original/${id}/${Date.now()}-${filename}`;

  const credential = new StorageSharedKeyCredential(accountName, accountKey);
  const sas = generateBlobSASQueryParameters({
    containerName: containers.hotels,
    blobName,
    permissions: BlobSASPermissions.parse('cw'),
    expiresOn: new Date(Date.now() + 5 * 60 * 1000),
    contentType,
  }, credential).toString();

  const baseUrl  = `https://${accountName}.blob.core.windows.net/${containers.hotels}/${blobName}`;
  const uploadUrl = `${baseUrl}?${sas}`;

  return { uploadUrl, imageUrl: baseUrl, key: blobName };
}

async function getS3ImageUploadUrl(id: string, filename: string, contentType: string) {
  const timestamp = Date.now();
  const s3        = new S3Client({ region: config.s3.region });
  const key       = `hotels/original/${id}/${timestamp}-${filename}`;

  const command   = new PutObjectCommand({
    Bucket:      config.s3.imagesBucket,
    Key:         key,
    ContentType: contentType,
  });
  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });

  // 저장할 이미지 URL (원본) — Lambda 리사이즈 완료 후 medium으로 교체 예정
  const imageUrl = `https://${config.s3.imagesBucket}.s3.${config.s3.region}.amazonaws.com/${key}`;

  return { uploadUrl, imageUrl, key };
}

export async function getImageUploadUrl(req: Request, res: Response): Promise<void> {
  if (config.mode !== 'azure' && !config.s3.imagesBucket) {
    res.status(503).json({ success: false, message: 'S3 이미지 버킷이 설정되지 않았습니다.' });
    return;
  }

  try {
    const { id } = req.params;
    const { filename, contentType = 'image/jpeg' } = req.query as { filename: string; contentType?: string };

    if (!filename) {
      res.status(400).json({ success: false, message: 'filename이 필요합니다.' });
      return;
    }

    const result = config.mode === 'azure'
      ? await getAzureImageUploadUrl(id, filename, contentType)
      : await getS3ImageUploadUrl(id, filename, contentType);

    res.json({ success: true, data: result });
  } catch (error) {
    logger.error('Get image upload URL error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
