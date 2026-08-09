import { ProviderError, type ImageProvider } from '../types.ts';

/**
 * FLUX عبر Black Forest Labs — المزوّد الافتراضي للصور.
 *
 * سبب الاختيار: يتصدّر جودة تصوير المنتجات الفوتوغرافي بسعر تنافسي، وهو
 * بالضبط ما نحتاجه هنا لأننا لا نطلب منه رسم أي نص (انظر promptbook/image.ts).
 *
 * الواجهة غير متزامنة: نرسل الطلب ثم نستعلم عن النتيجة.
 */
export class FluxImageProvider implements ImageProvider {
  readonly name = 'flux';

  constructor(
    private readonly apiKey: string,
    private readonly model = 'flux-pro-1.1',
    private readonly pollTimeoutMs = 60_000,
  ) {}

  async generate(input: {
    prompt: string;
    negativePrompt?: string;
    aspectRatio?: string;
  }): Promise<{ imageBase64: string; mimeType: string }> {
    const { width, height } = dimensionsFor(input.aspectRatio);

    const submit = await this.request(`https://api.bfl.ai/v1/${this.model}`, {
      prompt: input.prompt,
      width,
      height,
      output_format: 'png',
      safety_tolerance: 2,
    });

    const pollingUrl = submit.polling_url;
    const id = submit.id;
    if (!pollingUrl && !id) {
      throw new ProviderError('FLUX لم يُعد معرّف مهمة', this.name);
    }

    const imageUrl = await this.poll(pollingUrl ?? `https://api.bfl.ai/v1/get_result?id=${id}`);
    const bytes = await this.download(imageUrl);
    return { imageBase64: bytes, mimeType: 'image/png' };
  }

  private async request(url: string, body: unknown): Promise<FluxSubmitResponse> {
    let res: Response;
    try {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-key': this.apiKey },
        body: JSON.stringify(body),
      });
    } catch (cause) {
      throw new ProviderError(`تعذّر الوصول إلى FLUX: ${String(cause)}`, this.name, undefined, true);
    }
    if (!res.ok) {
      const text = await res.text().catch(() => '');
      throw new ProviderError(
        `FLUX رفض الطلب (${res.status}): ${text.slice(0, 300)}`,
        this.name,
        res.status,
        res.status === 429 || res.status >= 500,
      );
    }
    return (await res.json()) as FluxSubmitResponse;
  }

  private async poll(pollingUrl: string): Promise<string> {
    const deadline = Date.now() + this.pollTimeoutMs;
    let delay = 700;

    while (Date.now() < deadline) {
      await sleep(delay);
      delay = Math.min(delay * 1.4, 4000);

      const res = await fetch(pollingUrl, { headers: { 'x-key': this.apiKey } });
      if (!res.ok) continue;

      const json = (await res.json()) as FluxResultResponse;
      if (json.status === 'Ready' && json.result?.sample) return json.result.sample;
      if (json.status === 'Error' || json.status === 'Content Moderated') {
        throw new ProviderError(`FLUX أوقف التوليد: ${json.status}`, this.name);
      }
    }
    throw new ProviderError('انتهت مهلة انتظار FLUX', this.name, undefined, true);
  }

  private async download(url: string): Promise<string> {
    const res = await fetch(url);
    if (!res.ok) throw new ProviderError('تعذّر تنزيل صورة FLUX', this.name, res.status, true);
    const buf = Buffer.from(await res.arrayBuffer());
    return buf.toString('base64');
  }
}

/** أبعاد مضاعفات 32 كما تتوقعها نماذج الانتشار. */
export function dimensionsFor(aspectRatio?: string): { width: number; height: number } {
  switch (aspectRatio) {
    case '9:16':
      return { width: 768, height: 1344 };
    case '4:5':
      return { width: 864, height: 1080 };
    case '1:1':
    default:
      return { width: 1024, height: 1024 };
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

interface FluxSubmitResponse {
  id?: string;
  polling_url?: string;
}
interface FluxResultResponse {
  status?: string;
  result?: { sample?: string };
}
