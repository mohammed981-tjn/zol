import express, { type Request, type Response, type NextFunction } from 'express';
import { z } from 'zod';

import { allowedOriginsFromEnv, cors } from './lib/cors.ts';
import { generateCopy, generateImage } from './lib/generate.ts';
import {
  InMemoryUsageStore,
  Metering,
  PLANS,
  QuotaExceededError,
  type PlanId,
  type UsageStore,
} from './lib/metering.ts';
import { PLATFORMS } from './promptbook/platforms.ts';
import { TONES } from './promptbook/tones.ts';
import { MockImageProvider, MockTextProvider } from './providers/mock.ts';
import { AnthropicTextProvider } from './providers/text/anthropic.ts';
import { GeminiTextProvider } from './providers/text/gemini.ts';
import { FluxImageProvider } from './providers/image/flux.ts';
import { ProviderError, type ImageProvider, type TextProvider } from './providers/types.ts';

/**
 * المنسّق (Orchestrator).
 *
 * قاعدة أمنية غير قابلة للتفاوض: مفاتيح المزوّدين تُقرأ من بيئة الخادم فقط،
 * ولا تُرسل إلى التطبيق ولا تُخزَّن فيه أبداً (الخطر R4 في دراسة الجدوى).
 */

const briefSchema = z.object({
  productName: z.string().trim().min(2).max(80),
  productDescription: z.string().trim().max(500).optional(),
  tone: z.enum(TONES),
  platform: z.enum(PLATFORMS),
  visualContext: z.string().trim().max(500).optional(),
  brandName: z.string().trim().max(60).optional(),
});

export interface AppDeps {
  textProvider: TextProvider;
  imageProvider: ImageProvider;
  usageStore?: UsageStore;
  /** أصول الويب المسموح لها بمناداة المنسّق. */
  allowedOrigins?: string[];
  /** يُستخرج عادةً من رمز المصادقة؛ مبسَّط هنا حتى تُبنى المصادقة. */
  resolveAccount?: (req: Request) => { accountId: string; plan: PlanId };
}

export function buildProvidersFromEnv(env = process.env): {
  textProvider: TextProvider;
  imageProvider: ImageProvider;
  mock: boolean;
} {
  const mock = env.MOCK_MODE === '1' || env.MOCK_MODE === 'true';
  if (mock) {
    return { textProvider: new MockTextProvider(), imageProvider: new MockImageProvider(), mock: true };
  }

  const textChoice = (env.TEXT_PROVIDER ?? 'gemini').toLowerCase();
  let textProvider: TextProvider;
  if (textChoice === 'anthropic') {
    const key = requireKey(env.ANTHROPIC_API_KEY, 'ANTHROPIC_API_KEY');
    textProvider = new AnthropicTextProvider(key, env.ANTHROPIC_MODEL);
  } else {
    const key = requireKey(env.GEMINI_API_KEY, 'GEMINI_API_KEY');
    textProvider = new GeminiTextProvider(key, env.GEMINI_MODEL);
  }

  const imageKey = requireKey(env.BFL_API_KEY, 'BFL_API_KEY');
  const imageProvider = new FluxImageProvider(imageKey, env.FLUX_MODEL);

  return { textProvider, imageProvider, mock: false };
}

function requireKey(value: string | undefined, name: string): string {
  if (!value || !value.trim()) {
    throw new Error(
      `المفتاح ${name} غير مضبوط. اضبطه في بيئة الخادم، أو شغّل بـ MOCK_MODE=1 للتجربة بلا مفاتيح.`,
    );
  }
  return value.trim();
}

const defaultResolveAccount = (req: Request): { accountId: string; plan: PlanId } => {
  // مؤقت حتى تُبنى المصادقة: الحساب من ترويسة، والخطة مجانية افتراضاً.
  const accountId = String(req.header('x-account-id') ?? 'anonymous');
  const planHeader = String(req.header('x-account-plan') ?? 'free');
  const plan: PlanId = planHeader === 'pro' ? 'pro' : 'free';
  return { accountId, plan };
};

export function createApp(deps: AppDeps) {
  const app = express();
  app.use(cors(deps.allowedOrigins ?? allowedOriginsFromEnv()));
  app.use(express.json({ limit: '1mb' }));

  const metering = new Metering(deps.usageStore ?? new InMemoryUsageStore());
  const resolveAccount = deps.resolveAccount ?? defaultResolveAccount;

  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      textProvider: deps.textProvider.name,
      imageProvider: deps.imageProvider.name,
    });
  });

  app.get('/api/options', (_req, res) => {
    res.json({ tones: TONES, platforms: PLATFORMS, plans: PLANS });
  });

  app.get('/api/usage', async (req, res, next) => {
    try {
      const { accountId, plan } = resolveAccount(req);
      res.json({ plan, ...(await metering.status(accountId, plan)) });
    } catch (err) {
      next(err);
    }
  });

  /**
   * المعاينة الرخيصة: نص + صورة واحدة.
   * لا فيديو هنا إطلاقاً — الفيديو خلف بوابة الالتزام كما توصي الدراسة.
   */
  app.post('/api/generate/preview', async (req, res, next) => {
    try {
      const brief = briefSchema.parse(req.body);
      const { accountId, plan } = resolveAccount(req);

      // الحجز قبل أي استدعاء مكلف — هذا موضع الضابط الصحيح.
      const quota = await metering.reservePreview(accountId, plan);

      const wantImage = req.body?.includeImage !== false;
      const critique = req.body?.critique !== false;

      const [copy, image] = await Promise.all([
        generateCopy(deps.textProvider, brief, { critique }),
        wantImage ? generateImage(deps.imageProvider, brief) : Promise.resolve(null),
      ]);

      res.json({
        copy,
        image: image
          ? {
              base64: image.imageBase64,
              mimeType: image.mimeType,
              aspectRatio: image.aspectRatio,
              provider: image.provider,
            }
          : null,
        quota,
        // تنبيه صريح للواجهة: النص العربي يُركَّب في التطبيق لا داخل الصورة.
        textOverlayRequired: true,
      });
    } catch (err) {
      next(err);
    }
  });

  /** النص وحده — أرخص مسار، مفيد لإعادة الصياغة بلا إعادة توليد صورة. */
  app.post('/api/generate/copy', async (req, res, next) => {
    try {
      const brief = briefSchema.parse(req.body);
      const { accountId, plan } = resolveAccount(req);
      const quota = await metering.reservePreview(accountId, plan);
      const copy = await generateCopy(deps.textProvider, brief, {
        critique: req.body?.critique !== false,
      });
      res.json({ copy, quota });
    } catch (err) {
      next(err);
    }
  });

  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof QuotaExceededError) {
      res.status(429).json({
        error: 'quota_exceeded',
        message: err.message,
        plan: err.plan,
        limit: err.limit,
      });
      return;
    }
    if (err instanceof z.ZodError) {
      res.status(400).json({
        error: 'invalid_request',
        message: 'بيانات الطلب غير مكتملة أو غير صحيحة',
        issues: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })),
      });
      return;
    }
    if (err instanceof ProviderError) {
      res.status(err.retryable ? 503 : 502).json({
        error: 'provider_error',
        message: err.message,
        provider: err.provider,
        retryable: err.retryable,
      });
      return;
    }
    const message = err instanceof Error ? err.message : 'خطأ غير متوقع';
    res.status(500).json({ error: 'internal_error', message });
  });

  return app;
}
