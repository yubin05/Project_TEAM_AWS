import { config } from '../config';
import logger from '../utils/logger';

interface RatingMessage {
  hotelId: string;
  action: 'create' | 'delete';
  rating?: number;
}

export async function publishRatingUpdate(msg: RatingMessage): Promise<void> {
  try {
    const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
    const client = new SQSClient({ region: config.sqs.region });
    await client.send(new SendMessageCommand({
      QueueUrl:    config.sqs.queueUrl,
      MessageBody: JSON.stringify(msg),
    }));
    logger.info('SQS message sent', { hotelId: msg.hotelId, action: msg.action });
  } catch (err) {
    logger.error('SQS publish failed', { err });
  }
}
