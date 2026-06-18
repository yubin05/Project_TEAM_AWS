const { app } = require('@azure/functions');
const { BlobServiceClient } = require('@azure/storage-blob');
const sharp = require('sharp');

const THUMBNAIL_WIDTH  = parseInt(process.env.THUMBNAIL_WIDTH  || '400');
const THUMBNAIL_HEIGHT = parseInt(process.env.THUMBNAIL_HEIGHT || '300');

// AWS image-resize Lambda의 Azure 대응판.
// AWS 장애(Azure Active) 중 hotels 컨테이너의 original/ 에 업로드된 이미지를
// 리사이즈해 thumbnails/ 에 저장한다. (AWS 복구 후에는 image-resize Lambda가 다시 담당)
app.storageBlob('blobResize', {
  path: 'hotels/original/{name}',
  connection: 'AzureWebJobsStorage',
  handler: async (blob, context) => {
    const name = context.triggerMetadata.name;
    const originalBuffer = Buffer.from(blob);

    context.log(`Processing: hotels/original/${name} → hotels/thumbnails/${name}`);

    const resizedBuffer = await sharp(originalBuffer)
      .resize(THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, { fit: 'cover', position: 'centre' })
      .jpeg({ quality: 85 })
      .toBuffer();

    const blobServiceClient = BlobServiceClient.fromConnectionString(process.env.AzureWebJobsStorage);
    const blockBlobClient = blobServiceClient
      .getContainerClient('hotels')
      .getBlockBlobClient(`thumbnails/${name}`);

    await blockBlobClient.upload(resizedBuffer, resizedBuffer.length, {
      blobHTTPHeaders: { blobContentType: 'image/jpeg' },
    });

    context.log(`Thumbnail saved: hotels/thumbnails/${name} (${resizedBuffer.length} bytes)`);
  },
});
