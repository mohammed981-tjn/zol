import { ProviderError, type TextProvider } from '../types.ts';

/**
 * Anthropic — بديل قوي للنص، ومنافس مباشر في الأداء العربي.
 * موجود ليثبت أن طبقة المحوّلات تعمل فعلاً: تبديل TEXT_PROVIDER يكفي.
 */
export class AnthropicTextProvider implements TextProvider {
  readonly name = 'anthropic';

  constructor(
    private readonly apiKey: string,
    private readonly model = 'claude-haiku-4-5-20251001',
  ) {}

  async complete(input: {
    system: string;
    user: string;
    maxOutputTokens?: number;
    temperature?: number;
  }): Promise<{ text: string; usage?: { inputTokens?: number; outputTokens?: number } }> {
    let res: Response;
    try {
      res = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: this.model,
          max_tokens: input.maxOutputTokens ?? 2048,
          temperature: input.temperature ?? 0.9,
          system: input.system,
          messages: [{ role: 'user', content: input.user }],
        }),
      });
    } catch (cause) {
      throw new ProviderError(
        `تعذّر الوصول إلى Anthropic: ${String(cause)}`,
        this.name,
        undefined,
        true,
      );
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      throw new ProviderError(
        `Anthropic رفض الطلب (${res.status}): ${body.slice(0, 300)}`,
        this.name,
        res.status,
        res.status === 429 || res.status >= 500,
      );
    }

    const json = (await res.json()) as AnthropicResponse;
    const text = json.content?.map((b) => (b.type === 'text' ? b.text : '')).join('') ?? '';
    if (!text.trim()) throw new ProviderError('Anthropic أعاد رداً فارغاً', this.name);

    return {
      text,
      usage: {
        inputTokens: json.usage?.input_tokens,
        outputTokens: json.usage?.output_tokens,
      },
    };
  }
}

interface AnthropicResponse {
  content?: Array<{ type: string; text?: string }>;
  usage?: { input_tokens?: number; output_tokens?: number };
}
