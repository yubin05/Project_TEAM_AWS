import { TranslateClient, TranslateTextCommand } from '@aws-sdk/client-translate';
import { config, isLocal } from '../config';
import { getCachedTranslation, setCachedTranslation } from '../models/dynamo';

const translateClient = new TranslateClient({ region: config.translate.region });

/**
 * 텍스트를 대상 언어로 번역.
 * - 로컬 모드: 번역 API 호출 없이 원본 반환 (mock)
 * - AWS 모드: DynamoDB 캐시 우선 조회 → 없으면 Amazon Translate 호출 후 캐시 저장
 */
export async function translateText(
  text: string,
  targetLang: string,
  sourceLang = 'ko'
): Promise<string> {
  if (!text) return text;
  if (targetLang === sourceLang) return text;

  // 로컬 모드: mock 반환
  if (isLocal) return text;

  // AWS 모드: 캐시 확인
  const cached = await getCachedTranslation(text, targetLang);
  if (cached) return cached;

  // Amazon Translate 호출
  try {
    const { TranslatedText } = await translateClient.send(
      new TranslateTextCommand({
        Text: text,
        SourceLanguageCode: sourceLang,
        TargetLanguageCode: targetLang,
      })
    );
    await setCachedTranslation(text, targetLang, TranslatedText!);
    return TranslatedText!;
  } catch (err) {
    console.error('Translate error:', err);
    return text; // 실패 시 원본 반환
  }
}

/**
 * 객체 배열의 지정 필드들을 일괄 번역
 */
export async function translateFields<T extends Record<string, any>>(
  items: T[],
  fields: (keyof T)[],
  targetLang: string
): Promise<T[]> {
  if (isLocal || targetLang === 'ko') return items;

  return Promise.all(
    items.map(async (item) => {
      const translated = { ...item };
      for (const field of fields) {
        if (typeof item[field] === 'string') {
          (translated as any)[field] = await translateText(item[field], targetLang);
        }
      }
      return translated;
    })
  );
}
