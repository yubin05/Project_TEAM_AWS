import { Request, Response } from 'express';
import { config, isLocal } from '../config';
import logger from '../utils/logger';

let getSignedUrl: any;
let PutObjectCommand: any;
let S3Client: any;

if (!isLocal) {
  const s3Mod      = require('@aws-sdk/client-s3');
  const presignMod = require('@aws-sdk/s3-request-presigner');
  S3Client         = s3Mod.S3Client;
  PutObjectCommand = s3Mod.PutObjectCommand;
  getSignedUrl     = presignMod.getSignedUrl;
}

export async function getImageUploadUrl(req: Request, res: Response): Promise<void> {
  if (isLocal) {
    res.status(503).json({ success: false, message: '이미지 업로드는 AWS 환경에서만 지원됩니다.' });
    return;
  }
  if (!config.s3.imagesBucket) {
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

    res.json({ success: true, data: { uploadUrl, imageUrl, key } });
  } catch (error) {
    logger.error('Get image upload URL error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
