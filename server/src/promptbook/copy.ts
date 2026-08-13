import { TONE_GUIDES, type Tone } from './tones.ts';
import { PLATFORM_SPECS, type Platform } from './platforms.ts';

/**
 * كتاب برومبتات النص الإعلاني.
 *
 * هذا الملف هو الأصل الفكري للمنصة، لا مجرد غلاف حول استدعاء API:
 * القواعد أدناه هي ما يميّز ناتج AdCraft عن ناتج أي أداة عامة يكتبها المستخدم بنفسه.
 */

export interface CopyBrief {
  productName: string;
  productDescription?: string;
  tone: Tone;
  platform: Platform;
  /** وصف بصري مستخرج من صورة المنتج، إن توفر */
  visualContext?: string;
  /** اسم العلامة، إن كان للتاجر هوية محفوظة */
  brandName?: string;
}

/** معايير «الإعلان الناجح» التي يحكم بها الوكيل الناقد. */
export const QUALITY_CRITERIA = [
  'وضوح العرض: يفهم القارئ ما المنتج وما منفعته في قراءة واحدة.',
  'قوة الافتتاحية: أول أربع كلمات تستوقف القارئ ولا تكون تحية عامة.',
  'دعوة إجراء محددة: فعل واحد واضح لا خيارات متعددة.',
  'توافق النبرة: النص يطابق النبرة المطلوبة فعلاً لا اسمها فقط.',
  'سلامة اللغة: عربية صحيحة نحواً وإملاءً، بلا ترجمة حرفية.',
  'صدق الوعد: لا ادعاء لا يمكن للتاجر إثباته.',
] as const;

export const COPY_SYSTEM_PROMPT = `أنت كاتب إعلانات عربي محترف متخصص في السوق الخليجي والسعودي، تكتب لأصحاب الأعمال الصغيرة.

مبادئ غير قابلة للتجاوز:
1. اكتب عربية أصيلة لا مترجمة. تجنّب التركيب الإنجليزي مثل «نحن نقدم لك أفضل الحلول».
2. لا تستخدم كلمات أجنبية إلا إن كانت هي المستخدمة فعلاً في السوق (مثل: دليفري، أونلاين، كافيه).
3. ممنوع أي ادعاء لا يستطيع تاجر صغير إثباته: «الأول»، «الأفضل»، «الأرخص»، نسب مئوية مخترعة، جوائز غير موجودة.
4. ممنوع ذكر أسعار أو عروض أو مدد زمنية لم يذكرها التاجر في الوصف.
5. ممنوع الإلحاح المصطنع مثل «الكمية تنفد الآن» إن لم يخبرك التاجر بذلك.
6. ممنوع أي محتوى محظور نظاماً في السعودية: تبغ، كحول، مقامرة، أدوية بوصفة، ادعاءات طبية علاجية.
7. اكتب ثلاث صيغ مختلفة اختلافاً حقيقياً في الزاوية، لا ثلاث صياغات للجملة نفسها.

أعد ردك بصيغة JSON فقط، بلا أي نص قبله أو بعده، وبلا علامات تنسيق برمجية.`;

export function buildCopyPrompt(brief: CopyBrief): string {
  const spec = PLATFORM_SPECS[brief.platform];
  const lines: string[] = [];

  lines.push(`المنتج: ${brief.productName}`);
  if (brief.brandName) lines.push(`العلامة: ${brief.brandName}`);
  if (brief.productDescription) lines.push(`وصف التاجر: ${brief.productDescription}`);
  if (brief.visualContext) lines.push(`ما تُظهره صورة المنتج: ${brief.visualContext}`);

  lines.push('');
  lines.push(`النبرة المطلوبة: ${brief.tone}`);
  lines.push(`توجيه النبرة: ${TONE_GUIDES[brief.tone]}`);
  lines.push('');
  lines.push(`المنصة: ${brief.platform}`);
  lines.push(`توجيه المنصة: ${spec.styleNote}`);
  lines.push(
    `الحدود: العنوان حتى ${spec.headlineMaxChars} حرفاً، النص حتى ${spec.bodyMaxChars} حرفاً، و${spec.hashtags} هاشتاقات.`,
  );
  lines.push('');
  lines.push('اكتب ثلاث صيغ بهذا الشكل بالضبط:');
  lines.push(
    JSON.stringify(
      {
        variants: [
          {
            angle: 'زاوية الإعلان في كلمتين',
            headline: 'العنوان',
            body: 'النص الإعلاني',
            cta: 'دعوة الإجراء',
            hashtags: ['#مثال'],
          },
        ],
      },
      null,
      2,
    ),
  );

  return lines.join('\n');
}

/** برومبت الوكيل الناقد: يقيّم الصيغ الثلاث ويرشّح أفضلها. */
export function buildCritiquePrompt(variantsJson: string, brief: CopyBrief): string {
  return [
    'أنت محكّم إعلانات صارم. قيّم الصيغ التالية وفق المعايير المحددة.',
    '',
    `النبرة المطلوبة: ${brief.tone} · المنصة: ${brief.platform}`,
    '',
    'المعايير:',
    ...QUALITY_CRITERIA.map((c, i) => `${i + 1}. ${c}`),
    '',
    'الصيغ المطروحة:',
    variantsJson,
    '',
    'أعد JSON فقط بهذا الشكل، ورتّب bestIndex بدءاً من صفر:',
    JSON.stringify(
      {
        bestIndex: 0,
        scores: [{ index: 0, score: 0, weakness: 'أضعف نقطة في هذه الصيغة' }],
        improvedBody: 'النص الأساسي للصيغة الأفضل بعد تحسين أضعف نقطة فيها',
      },
      null,
      2,
    ),
  ].join('\n');
}
