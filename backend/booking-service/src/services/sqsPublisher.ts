import { config } from '../config';
import logger from '../utils/logger';

export interface BookingNotificationMessage {
  bookingId:  string;
  userEmail:  string;
  userName:   string;
  hotelName:  string;
  roomName:   string;
  checkIn:    string;
  checkOut:   string;
  guests:     number;
  totalPrice: number;
  nights:     number;
}

export async function publishBookingNotification(msg: BookingNotificationMessage): Promise<void> {
  try {
    const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');

    const client = new SQSClient({ region: config.sqs.region });
    await client.send(new SendMessageCommand({
      QueueUrl:    config.sqs.queueUrl,
      MessageBody: JSON.stringify(msg),
    }));
    logger.info('Booking notification sent to SQS', { bookingId: msg.bookingId });
  } catch (err) {
    // 이메일 알림 실패가 예약 응답에 영향 주지 않도록 에러를 삼킴
    logger.error('SQS booking notification failed', { err });
  }
}
