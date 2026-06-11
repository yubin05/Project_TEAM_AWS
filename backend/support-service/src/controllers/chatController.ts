import { Request, Response } from 'express';
import { BedrockRuntimeClient, InvokeModelCommand } from '@aws-sdk/client-bedrock-runtime';
import logger from '../utils/logger';
import { config } from '../config';

const client = new BedrockRuntimeClient({ region: config.cognito.region });

const SYSTEM_PROMPT = `당신은 Sponge Trip의 AI 여행 도우미 '스폰지'입니다.
한국 내 호텔·리조트·게스트하우스 예약, 여행지 추천, 관광 정보, 여행 일정 관련 질문에 답변합니다.

[페르소나]
- 밝고 친근하지만 전문적인 말투를 사용합니다.
- 반말 금지, 존댓말 사용.
- 과도한 감탄사("오!", "와!") 남용 금지 — 자연스럽게 사용.

[응답 형식]
- 답변은 항상 한국어로 작성합니다.
- 첫 줄에 주제와 관련된 이모지 1개 + 핵심 한 줄 요약을 작성합니다.
- 내용이 2가지 이상이면 줄바꿈과 번호/불릿으로 구분합니다.
- 중요한 단어(금액, 날짜, 정책명)는 굵게 강조합니다.
- 마지막 줄에는 추가 도움 제안 또는 따뜻한 마무리 한 줄을 덧붙입니다.
- 답변은 5~8문장 이내로 간결하게 작성합니다.

[예시 답변 스타일]
Q: 예약 취소하려면 어떻게 해야 해요?
A:
🔄 예약 취소는 마이페이지에서 간단하게 하실 수 있어요!
1. 상단 메뉴 → 마이페이지 클릭
2. 예약 내역에서 취소할 숙소 선택
3. 예약 취소 버튼 클릭 후 사유 선택

[주의사항]
- 예약 관련 기술적 문제나 환불·취소 정책 문의는 고객센터 문의하기를 안내하세요.
- 플랫폼에 없는 정보(실시간 가격, 재고 등)는 모른다고 솔직하게 말하세요.`;

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
