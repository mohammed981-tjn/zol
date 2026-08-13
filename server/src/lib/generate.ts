import {
  buildCopyPrompt,
  buildCritiquePrompt,
  COPY_SYSTEM_PROMPT,
  type CopyBrief,
} from '../promptbook/copy.ts';
import { aspectRatioFor, buildImagePrompt, IMAGE_NEGATIVE_PROMPT } from '../promptbook/image.ts';
import { PLATFORM_SPECS } from '../promptbook/platforms.ts';
import type { ImageProvider, TextProvider } from '../providers/types.ts';

export interface CopyVariant {
  angle: string;
  headline: string;
  body: string;
  cta: string;
  hashtags: string[];
}

export interface CopyResult {
  variants: CopyVariant[];
  /** فهرس الصيغة التي رشّحها الوكيل الناقد */
  bestIndex: number;
  /** هل جرى تمرير النقد فعلاً؟ */
  critiqued: boolean;
  provider: string;
}

/**
 * يستخرج JSON من رد النموذج بتسامح: بعض النماذج تُحيط الرد بأسوار برمجية
 * أو بجملة تمهيدية رغم التعليمات، والفشل هنا يعني فشل الطلب كله.
 */
export function extractJson(raw: string): unknown {
  const trimmed = raw.trim();

  const fenced = /```(?:json)?\s*([\s\S]*?)```/.exec(trimmed);
  const candidate = fenced?.[1]?.trim() ?? trimmed;

  try {
    return JSON.parse(candidate);
  } catch {
    // آخر محاولة: أول كائن متوازن الأقواس في النص
    const start = candidate.indexOf('{');
    const end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return JSON.parse(candidate.slice(start, end + 1));
    }
    throw new Error('رد النموذج ليس JSON صالحاً');
  }
}

/** يقصّ النص على الحد الآمن للمنصة بلا قطع كلمة في منتصفها. */
export function clampToWords(text: string, maxChars: number): string {
  const clean = text.trim().replace(/\s+/g, ' ');
  if (clean.length <= maxChars) return clean;
  const cut = clean.slice(0, maxChars);
  const lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > maxChars * 0.6 ? cut.slice(0, lastSpace) : cut).trim();
}

function normalizeVariant(v: unknown, brief: CopyBrief): CopyVariant | null {
  if (typeof v !== 'object' || v === null) return null;
  const o = v as Record<string, unknown>;
  const spec = PLATFORM_SPECS[brief.platform];

  const headline = typeof o.headline === 'string' ? o.headline : '';
  const body = typeof o.body === 'string' ? o.body : '';
  if (!headline.trim() || !body.trim()) return null;

  const hashtags = Array.isArray(o.hashtags)
    ? o.hashtags
        .filter((h): h is string => typeof h === 'string' && h.trim().length > 1)
        .map((h) => (h.startsWith('#') ? h : `#${h}`).replace(/\s+/g, '_'))
        .slice(0, spec.hashtags)
    : [];

  return {
    angle: typeof o.angle === 'string' ? o.angle.trim() : '',
    headline: clampToWords(headline, spec.headlineMaxChars),
    body: clampToWords(body, spec.bodyMaxChars),
    cta: typeof o.cta === 'string' ? clampToWords(o.cta, 24) : 'اطلبه الآن',
    hashtags,
  };
}

export async function generateCopy(
  text: TextProvider,
  brief: CopyBrief,
  options: { critique: boolean } = { critique: true },
): Promise<CopyResult> {
  const first = await text.complete({
    system: COPY_SYSTEM_PROMPT,
    user: buildCopyPrompt(brief),
    temperature: 0.95,
  });

  const parsed = extractJson(first.text) as { variants?: unknown };
  const rawVariants = Array.isArray(parsed.variants) ? parsed.variants : [];
  const variants = rawVariants
    .map((v) => normalizeVariant(v, brief))
    .filter((v): v is CopyVariant => v !== null);

  if (variants.length === 0) {
    throw new Error('لم يُنتج النموذج أي صيغة صالحة');
  }

  if (!options.critique || variants.length < 2) {
    return { variants, bestIndex: 0, critiqued: false, provider: text.name };
  }

  // تمرير الوكيل الناقد — يكلّف نحو سنت واحد ويرفع الجودة بترشيح مسنَد لمعايير.
  try {
    const critique = await text.complete({
      system: 'أنت محكّم إعلانات صارم. تُعيد JSON فقط.',
      user: buildCritiquePrompt(JSON.stringify({ variants }, null, 2), brief),
      temperature: 0.2,
    });

    const verdict = extractJson(critique.text) as {
      bestIndex?: unknown;
      improvedBody?: unknown;
    };

    let bestIndex = 0;
    if (typeof verdict.bestIndex === 'number' && Number.isInteger(verdict.bestIndex)) {
      if (verdict.bestIndex >= 0 && verdict.bestIndex < variants.length) {
        bestIndex = verdict.bestIndex;
      }
    }

    if (typeof verdict.improvedBody === 'string' && verdict.improvedBody.trim().length > 10) {
      const target = variants[bestIndex];
      if (target) {
        target.body = clampToWords(verdict.improvedBody, PLATFORM_SPECS[brief.platform].bodyMaxChars);
      }
    }

    return { variants, bestIndex, critiqued: true, provider: text.name };
  } catch {
    // فشل النقد لا يُفشل الطلب: نسلّم الصيغ كما هي.
    return { variants, bestIndex: 0, critiqued: false, provider: text.name };
  }
}

export interface ImageResult {
  imageBase64: string;
  mimeType: string;
  aspectRatio: string;
  /** البرومبت المستخدم — يُعاد للشفافية وتسهيل التشخيص */
  prompt: string;
  provider: string;
}

export async function generateImage(
  image: ImageProvider,
  brief: { productName: string; productDescription?: string; tone: CopyBrief['tone']; platform: CopyBrief['platform'] },
): Promise<ImageResult> {
  const prompt = buildImagePrompt(brief);
  const aspectRatio = aspectRatioFor(brief.platform);

  const out = await image.generate({
    prompt,
    negativePrompt: IMAGE_NEGATIVE_PROMPT,
    aspectRatio,
  });

  return {
    imageBase64: out.imageBase64,
    mimeType: out.mimeType,
    aspectRatio,
    prompt,
    provider: image.name,
  };
}
