import { PLATFORM_SPECS, type Platform } from './platforms.ts';
import type { Tone } from './tones.ts';

/**
 * كتاب برومبتات الصورة.
 *
 * قرار معماري مقصود: لا نطلب من نموذج الصور أن يرسم نصاً عربياً أبداً.
 * نماذج توليد الصور تُشوّه العربية (حروف منفصلة أو معكوسة أو مقلوبة)، وحتى
 * النماذج الأفضل في رسم النص لا تُعتمد عليها للعربية بثبات. لذلك:
 *
 *   نموذج الصور  →  ينتج خلفية/مشهد المنتج فقط (بلا أي حروف)
 *   التطبيق      →  يركّب النص العربي كطبقة نصية حقيقية فوق الصورة
 *
 * الفائدة ثلاثية: طباعة عربية صحيحة دائماً، نص قابل للتعديل بعد التوليد،
 * وصفر إعادة توليد بسبب حروف مشوّهة.
 *
 * البرومبت يُكتب بالإنجليزية لأن نماذج الصور تفهمها أدق، بينما النص المعروض
 * للعميل يبقى عربياً بالكامل.
 */

export interface ImageBrief {
  productName: string;
  productDescription?: string;
  tone: Tone;
  platform: Platform;
}

/** توجيه بصري لكل نبرة: إضاءة، لون، تكوين. */
const TONE_LOOK: Record<Tone, string> = {
  حماسي: 'bold saturated colors, high contrast, dynamic diagonal composition, energetic studio lighting',
  كوميدي: 'bright playful colors, quirky props, soft even lighting, generous negative space',
  رسمي: 'restrained neutral palette, symmetrical composition, clean softbox lighting, premium minimal set',
  عاطفي: 'warm golden-hour light, shallow depth of field, soft natural textures, intimate close framing',
};

/** حجوزات بصرية للنص الذي سيُركَّب لاحقاً — تُترك مساحة فارغة مقصودة. */
const COMPOSITION_BY_RATIO: Record<string, string> = {
  '1:1': 'leave the upper third visually calm and uncluttered as empty space',
  '4:5': 'leave the lower third visually calm and uncluttered as empty space',
  '9:16': 'leave the top quarter and bottom quarter visually calm and uncluttered as empty space',
};

/**
 * أهم سطر في الملف: منع صريح ومكرر لأي شكل من الحروف.
 * التكرار مقصود — النماذج تميل لإضافة نص تلقائياً في سياق «إعلان».
 */
const NO_TEXT_RULE =
  'absolutely no text, no letters, no words, no numbers, no typography, no lettering, ' +
  'no captions, no labels, no signage, no logos, no watermarks, no UI elements anywhere in the image';

export function buildImagePrompt(brief: ImageBrief): string {
  const spec = PLATFORM_SPECS[brief.platform];
  const composition = COMPOSITION_BY_RATIO[spec.aspectRatio] ?? '';

  const subject = brief.productDescription
    ? `${brief.productName} — ${brief.productDescription}`
    : brief.productName;

  return [
    `Professional commercial product photograph of ${subject}.`,
    TONE_LOOK[brief.tone] + '.',
    composition ? composition + '.' : '',
    'Sharp focus on the product, realistic materials and shadows, advertising-grade quality.',
    NO_TEXT_RULE + '.',
  ]
    .filter(Boolean)
    .join(' ');
}

/** برومبت سلبي لمزوّدي الصور الذين يدعمونه. */
export const IMAGE_NEGATIVE_PROMPT =
  'text, letters, words, numbers, typography, captions, labels, signage, logo, watermark, ' +
  'arabic script, latin script, garbled characters, distorted product, extra limbs, low quality, blurry';

export function aspectRatioFor(platform: Platform): string {
  return PLATFORM_SPECS[platform].aspectRatio;
}
