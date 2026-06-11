import { Request, Response } from 'express';
import { BedrockRuntimeClient, InvokeModelCommand } from '@aws-sdk/client-bedrock-runtime';
import logger from '../utils/logger';
import { config } from '../config';

const client = new BedrockRuntimeClient({ region: config.cognito.region });

const SYSTEM_PROMPT = `당신은 스폰지니어(Spongineers) 여행 예약 플랫폼의 AI 여행 도우미입니다.
한국 내 호텔·리조트·게스트하우스 예약, 여행지 추천, 관광 정보, 여행 일정 관련 질문에 친절하게 답변합니다.
답변은 항상 한국어로 하고, 간결하고 실용적으로 작성하세요.
예약 관련 기술적 문제나 환불·취소 정책 문의는 고객센터 문의하기를 안내하세요.
플랫폼에 없는 정보(실시간 가격, 재고 등)는 모른다고 솔직하게 말하세요.`;

export async function chat(req: Request, res: Response): Promise<void> {
  const { message, history = [] } = req.body;

  if (!message?.trim()) {
    res.status(400).json({ success: false, message: '메시지를 입력해주세요.' });
    return;
  }

  // 최근 10개 메시지만 유지 (토큰 절약)
  const recentHistory = (history as { role: string; content: string }[]).slice(-10);

  try {
    const command = new InvokeModelCommand({
      modelId:     'anthropic.claude-3-haiku-20240307-v1:0',
      contentType: 'application/json',
      accept:      'application/json',
      body: JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [
          ...recentHistory,
          { role: 'user', content: message.trim() },
        ],
      }),
    });

    const response = await client.send(command);
    const output  = JSON.parse(Buffer.from(response.body).toString());
    const reply   = output.content?.[0]?.text ?? '답변을 생성할 수 없습니다.';

    res.json({ success: true, reply });
  } catch (err) {
    logger.error('Bedrock chat failed', { err });
    res.status(500).json({ success: false, message: 'AI 서비스에 일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요.' });
  }
}
