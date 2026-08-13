/**
 * قيود المنصات — أرقام تقريبية مقصودة للأمان لا حدود قصوى نظرية،
 * لأن الإعلان المقتطع أسوأ من الإعلان القصير.
 */

export const PLATFORMS = ['إنستغرام', 'تيك توك', 'فيسبوك', 'سناب شات'] as const;
export type Platform = (typeof PLATFORMS)[number];

export interface PlatformSpec {
  /** أقصى طول آمن للنص الأساسي بالأحرف */
  bodyMaxChars: number;
  /** أقصى طول للعنوان بالأحرف */
  headlineMaxChars: number;
  /** عدد الهاشتاقات الموصى به */
  hashtags: number;
  /** نسبة أبعاد الصورة المناسبة */
  aspectRatio: '1:1' | '4:5' | '9:16';
  /** توجيه أسلوبي خاص بالمنصة */
  styleNote: string;
}

export const PLATFORM_SPECS: Record<Platform, PlatformSpec> = {
  إنستغرام: {
    bodyMaxChars: 220,
    headlineMaxChars: 40,
    hashtags: 5,
    aspectRatio: '4:5',
    styleNote: 'جمهور بصري أولاً. الصورة تحمل الرسالة والنص يكملها. الهاشتاقات مقبولة ومتوقعة.',
  },
  'تيك توك': {
    bodyMaxChars: 150,
    headlineMaxChars: 30,
    hashtags: 4,
    aspectRatio: '9:16',
    styleNote:
      'الثانيتان الأولى تحددان كل شيء. ابدأ بالخطّاف لا بالتحية. لغة محادثة قريبة من الشباب بلا تصنّع.',
  },
  فيسبوك: {
    bodyMaxChars: 280,
    headlineMaxChars: 45,
    hashtags: 3,
    aspectRatio: '1:1',
    styleNote:
      'جمهور أوسع عمرياً ويقرأ نصاً أطول. الوضوح والمصداقية أهم من الإثارة. هاشتاقات قليلة.',
  },
  'سناب شات': {
    bodyMaxChars: 120,
    headlineMaxChars: 28,
    hashtags: 3,
    aspectRatio: '9:16',
    styleNote:
      'عمودي وسريع ومحلي الطابع. لهجة خليجية خفيفة مقبولة جداً هنا. اجعل العرض واضحاً فوراً.',
  },
};

export function isPlatform(v: unknown): v is Platform {
  return typeof v === 'string' && (PLATFORMS as readonly string[]).includes(v);
}
