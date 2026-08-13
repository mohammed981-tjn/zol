import { ProviderError, type TextProvider } from '../types.ts';

/**
 * Gemini — المزوّد الافتراضي للنص.
 *
 * سبب الاختيار: نماذج Gemini تتصدّر مؤشرات الأداء العربي العامة، وتوفّر طبقة
 * مجانية سخية للتجريب. لكن انتبه: شروط الطبقة المجانية تسمح باستخدام البيانات
 * لتحسين منتجات المزوّد، لذا لا يجوز تمرير محتوى تجّار حقيقي عبرها —
 * استخدم مفتاحاً على طبقة مدفوعة قبل أول عميل فعلي (الخطر R2 في الدراسة).
 */
export class GeminiTextProvider implements TextProvider {
  readonly name = 'gemini';

  constructor(
    private readonly apiKey: string,
    private readonly model = 'gemini-2.5-flash',
  ) {}

  async complete(input: {
    system: string;
    user: string;
    maxOutputTokens?: number;
    temperature?: number;
  }): Promise<{ text: string; usage?: { inputTokens?: number; outputTokens?: number } }> {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent`;

    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': this.apiKey,
        },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: input.system }] },
          contents: [{ role: 'user', parts: [{ text: input.user }] }],
          generationConfig: {
            temperature: input.temperature ?? 0.9,
            maxOutputTokens: input.maxOutputTokens ?? 2048,
            responseMimeType: 'application/json',
          },
        }),
      });
    } catch (cause) {
      throw new ProviderError(`تعذّر الوصول إلى Gemini: ${String(cause)}`, this.name, undefined, true);
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new ProviderError(
        `Gemini رفض الطلب (${res.status}): ${body.slice(0, 300)}`,
        this.name,
        res.status,
        res.status === 429 || res.status >= 500,
      );
    }

    const json = (await res.json()) as GeminiResponse;
    const text = json.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
    if (!text.trim()) {
      throw new ProviderError('Gemini أعاد رداً فارغاً', this.name);
    }

    return {
      text,
      usage: {
        inputTokens: json.usageMetadata?.promptTokenCount,
        outputTokens: json.usageMetadata?.candidatesTokenCount,
      },
    };
  }
}

interface GeminiResponse {
  candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
  usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number };
}
