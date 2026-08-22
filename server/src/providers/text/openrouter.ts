import { ProviderError, type TextProvider } from '../types.ts';

/**
 * OpenRouter — بوّابة واحدة أمام عشرات النماذج بمفتاح واحد.
 *
 * قيمته هنا شيئان: نماذج مجانية (لواحق `:free`) تشغّل التطبيق بلا فاتورة،
 * وتبديل النموذج بمتغيّر بيئة واحد دون لمس الشيفرة — فلا نرتهن لمزوّد بعينه.
 *
 * واجهته متوافقة مع OpenAI Chat Completions، فالجسم هنا هو الجسم القياسي.
 */
export class OpenRouterTextProvider implements TextProvider {
  readonly name = 'openrouter';

  constructor(
    private readonly apiKey: string,
    // نموذج مجاني افتراضاً: يعمل بلا رصيد، ويُبدَّل بـ OPENROUTER_MODEL.
    private readonly model = 'meta-llama/llama-3.3-70b-instruct:free',
    // OpenRouter يطلب هذين للتعريف بالتطبيق في لوحاته، وهما اختياريان.
    private readonly referer = 'https://github.com/mohammed981-tjn/zol',
    private readonly title = 'Zol AdCraft',
  ) {}

  async complete(input: {
    system: string;
    user: string;
    maxOutputTokens?: number;
    temperature?: number;
  }): Promise<{ text: string; usage?: { inputTokens?: number; outputTokens?: number } }> {
    let res: Response;
    try {
      res = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${this.apiKey}`,
          'HTTP-Referer': this.referer,
          'X-Title': this.title,
        },
        body: JSON.stringify({
          model: this.model,
          max_tokens: input.maxOutputTokens ?? 2048,
          temperature: input.temperature ?? 0.9,
          messages: [
            { role: 'system', content: input.system },
            { role: 'user', content: input.user },
          ],
        }),
      });
    } catch (cause) {
      throw new ProviderError(
        `تعذّر الوصول إلى OpenRouter: ${String(cause)}`,
        this.name,
        undefined,
        true,
      );
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new ProviderError(
        `OpenRouter رفض الطلب (${res.status}): ${body.slice(0, 300)}`,
        this.name,
        res.status,
        res.status === 429 || res.status >= 500,
      );
    }

    const json = (await res.json()) as OpenRouterResponse;

    // OpenRouter قد يعيد 200 ومعه خطأ في الجسم (حصة نموذج مجاني مثلاً)
    // بدل رمز حالة صريح، فلا يكفي فحص res.ok وحده.
    if (json.error) {
      throw new ProviderError(
        `OpenRouter أعاد خطأ: ${json.error.message ?? 'غير معروف'}`,
        this.name,
        json.error.code,
        json.error.code === 429,
      );
    }

    const text = json.choices?.[0]?.message?.content ?? '';
    if (!text.trim()) throw new ProviderError('OpenRouter أعاد رداً فارغاً', this.name);

    return {
      text,
      usage: {
        inputTokens: json.usage?.prompt_tokens,
        outputTokens: json.usage?.completion_tokens,
      },
    };
  }
}

interface OpenRouterResponse {
  choices?: Array<{ message?: { content?: string } }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
  error?: { message?: string; code?: number };
}
