/**
 * عقود المزوّدين.
 *
 * كل مزوّد يُخفى خلف هذه الواجهات، فتبديل نموذج أو شركة لا يمسّ بقية الشيفرة.
 * هذا هو الضابط المقترح للخطر R6 في دراسة الجدوى (تقلّب أسعار المزوّدين وتوافرهم).
 */

export interface TextProvider {
  readonly name: string;
  /** يُرجع نص الرد الخام من النموذج. */
  complete(input: {
    system: string;
    user: string;
    maxOutputTokens?: number;
    temperature?: number;
  }): Promise<{ text: string; usage?: TokenUsage }>;
}

export interface ImageProvider {
  readonly name: string;
  generate(input: {
    prompt: string;
    negativePrompt?: string;
    aspectRatio?: string;
  }): Promise<{ imageBase64: string; mimeType: string }>;
}

export interface TokenUsage {
  inputTokens?: number;
  outputTokens?: number;
}

export class ProviderError extends Error {
  constructor(
    message: string,
    readonly provider: string,
    readonly status?: number,
    readonly retryable = false,
  ) {
    super(message);
    this.name = 'ProviderError';
  }
}
