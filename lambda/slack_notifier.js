'use strict';

const https = require('https');
const { URL } = require('url');

exports.handler = async (event) => {
  const snsRecord = event.Records[0].Sns;

  let message;
  try {
    message = JSON.parse(snsRecord.Message);
  } catch {
    message = { AlarmDescription: snsRecord.Message };
  }

  const alarmName  = message.AlarmName        || snsRecord.Subject || '알람';
  const description = message.AlarmDescription || '-';
  const newState    = message.NewStateValue    || '-';
  const reason      = message.NewStateReason   || '-';
  const region      = message.Region           || '-';

  const emoji = newState === 'ALARM' ? ':red_circle:' : newState === 'OK' ? ':large_green_circle:' : ':white_circle:';
  const color = newState === 'ALARM' ? 'danger'       : newState === 'OK' ? 'good'               : 'warning';

  const body = JSON.stringify({
    text: `${emoji} *[${newState}] ${alarmName}*`,
    attachments: [{
      color,
      fields: [
        { title: '설명',   value: description, short: false },
        { title: '원인',   value: reason,       short: false },
        { title: '리전',   value: region,       short: true  },
        { title: '상태',   value: newState,     short: true  },
      ],
      footer: 'CloudWatch → SNS → Lambda → Slack',
      ts: Math.floor(Date.now() / 1000),
    }],
  });

  const webhookUrl = new URL(process.env.SLACK_WEBHOOK_URL);

  await new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: webhookUrl.hostname,
        path:     webhookUrl.pathname,
        method:   'POST',
        headers: {
          'Content-Type':   'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      (res) => {
        res.resume();
        res.on('end', resolve);
      }
    );
    req.on('error', reject);
    req.write(body);
    req.end();
  });

  console.log(`Slack 알림 전송 완료: ${alarmName} → ${newState}`);
};