import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

const ses = new SESClient({ region: process.env.AWS_REGION || 'ap-northeast-2' });
const FROM_EMAIL = process.env.FROM_EMAIL || 'noreply@yourdomain.com';

export const handler = async (event) => {
  for (const record of event.Records) {
    try {
      const msg = JSON.parse(record.body);
      await sendBookingEmail(msg);
    } catch (err) {
      console.error('Failed to process record', { err, record });
    }
  }
};

async function sendBookingEmail(msg) {
  const {
    bookingId, userEmail, userName,
    hotelName, roomName,
    checkIn, checkOut, guests, totalPrice, nights,
  } = msg;

  const formattedPrice = Math.floor(totalPrice).toLocaleString('ko-KR');
  const formattedCheckIn  = new Date(checkIn).toLocaleDateString('ko-KR');
  const formattedCheckOut = new Date(checkOut).toLocaleDateString('ko-KR');

  const html = `
<!DOCTYPE html>
<html lang="ko">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:Arial,sans-serif">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:40px 0">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.1)">
        <tr>
          <td style="background:#ff4f5e;padding:32px;text-align:center">
            <h1 style="color:#fff;margin:0;font-size:24px">✈️ 야놀자</h1>
            <p style="color:rgba(255,255,255,0.9);margin:8px 0 0;font-size:15px">예약이 확정되었습니다</p>
          </td>
        </tr>
        <tr>
          <td style="padding:32px">
            <p style="color:#333;font-size:16px;margin:0 0 24px">${userName}님, 예약해 주셔서 감사합니다!</p>
            <table width="100%" cellpadding="12" cellspacing="0" style="background:#f9f9f9;border-radius:8px;margin-bottom:24px">
              <tr>
                <td style="color:#888;font-size:14px;width:40%">예약 번호</td>
                <td style="color:#333;font-size:14px;font-weight:bold">${bookingId}</td>
              </tr>
              <tr style="border-top:1px solid #eee">
                <td style="color:#888;font-size:14px">숙소</td>
                <td style="color:#333;font-size:14px">${hotelName}</td>
              </tr>
              <tr style="border-top:1px solid #eee">
                <td style="color:#888;font-size:14px">객실</td>
                <td style="color:#333;font-size:14px">${roomName}</td>
              </tr>
              <tr style="border-top:1px solid #eee">
                <td style="color:#888;font-size:14px">체크인</td>
                <td style="color:#333;font-size:14px">${formattedCheckIn}</td>
              </tr>
              <tr style="border-top:1px solid #eee">
                <td style="color:#888;font-size:14px">체크아웃</td>
                <td style="color:#333;font-size:14px">${formattedCheckOut} (${nights}박)</td>
              </tr>
              <tr style="border-top:1px solid #eee">
                <td style="color:#888;font-size:14px">인원</td>
                <td style="color:#333;font-size:14px">${guests}명</td>
              </tr>
              <tr style="border-top:1px solid #eee">
                <td style="color:#888;font-size:14px">결제 금액</td>
                <td style="color:#ff4f5e;font-size:16px;font-weight:bold">${formattedPrice}원</td>
              </tr>
            </table>
            <p style="color:#888;font-size:13px;margin:0">문의: support@yanolza.com</p>
          </td>
        </tr>
        <tr>
          <td style="background:#f5f5f5;padding:16px;text-align:center">
            <p style="color:#aaa;font-size:12px;margin:0">© 2024 야놀자 Travel. All rights reserved.</p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

  await ses.send(new SendEmailCommand({
    Source: FROM_EMAIL,
    Destination: { ToAddresses: [userEmail] },
    Message: {
      Subject: { Data: `[야놀자] ${hotelName} 예약이 확정되었습니다`, Charset: 'UTF-8' },
      Body: { Html: { Data: html, Charset: 'UTF-8' } },
    },
  }));

  console.log('Booking email sent', { bookingId, userEmail });
}
