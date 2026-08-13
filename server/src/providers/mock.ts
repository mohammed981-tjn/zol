import zlib from 'node:zlib';

import type { ImageProvider, TextProvider } from './types.ts';
import { PLATFORM_SPECS } from '../promptbook/platforms.ts';
import { dimensionsFor } from './image/flux.ts';

/**
 * مزوّدون محاكيان.
 *
 * الغرض ليس اختبار الوحدات فقط: هما يجعلان المنصة كلها قابلة للتشغيل والعرض
 * بلا أي مفتاح ولا أي فاتورة — فتُجرَّب رحلة العميل من طرف إلى طرف قبل
 * التعاقد مع أي مزوّد. تفعيلهما بـ MOCK_MODE=1.
 *
 * الناتج مكتوب بعربية سليمة لا نص لاتيني وهمي، حتى يكون العرض واقعياً.
 */

export class MockTextProvider implements TextProvider {
  readonly name = 'mock';

  async complete(input: { system: string; user: string }): Promise<{ text: string }> {
    // نقد أم توليد؟ نميّز من شكل البرومبت لا من علم مسبق.
    if (input.user.includes('bestIndex')) {
      return {
        text: JSON.stringify({
          bestIndex: 0,
          scores: [
            { index: 0, score: 9, weakness: 'دعوة الإجراء كانت عامة قبل التحسين' },
            { index: 1, score: 7, weakness: 'الافتتاحية أطول من اللازم' },
            { index: 2, score: 6, weakness: 'النبرة أقرب للرسمي من المطلوب' },
          ],
          improvedBody: '',
        }),
      };
    }

    const product = /المنتج:\s*(.+)/.exec(input.user)?.[1]?.trim() ?? 'منتجك';
    const platform =
      (Object.keys(PLATFORM_SPECS) as Array<keyof typeof PLATFORM_SPECS>).find((p) =>
        input.user.includes(`المنصة: ${p}`),
      ) ?? 'إنستغرام';
    const tag = platform.replace(/\s/g, '_');

    return {
      text: JSON.stringify({
        variants: [
          {
            angle: 'المنفعة المباشرة',
            headline: `${product} صار أقرب`,
            body: `جرّب ${product} اليوم واكتشف الفرق بنفسك. جودة تستحق وسعر تفهمه.`,
            cta: 'اطلبه الآن',
            hashtags: ['#جودة', '#السعودية', `#${tag}`],
          },
          {
            angle: 'الموقف اليومي',
            headline: `يومك يحتاج ${product}`,
            body: `في الزحمة والوقت الضيق، ${product} يوفّر عليك خطوة. بساطة تُحسّ فيها من أول مرة.`,
            cta: 'ابدأ من هنا',
            hashtags: ['#سهولة', '#تجربة', `#${tag}`],
          },
          {
            angle: 'الثقة والاختيار',
            headline: `اختيار يريح البال`,
            body: `${product} مصنوع ليدوم. لأن أفضل شراء هو الذي لا تعيد التفكير فيه.`,
            cta: 'تعرّف أكثر',
            hashtags: ['#ثقة', '#اختيار_صحيح', `#${tag}`],
          },
        ],
      }),
    };
  }
}

export class MockImageProvider implements ImageProvider {
  readonly name = 'mock';

  async generate(input: { aspectRatio?: string }): Promise<{
    imageBase64: string;
    mimeType: string;
  }> {
    const { width, height } = dimensionsFor(input.aspectRatio);
    return { imageBase64: gradientPng(width, height), mimeType: 'image/png' };
  }
}

/**
 * يبني PNG حقيقياً (بلا أي تبعية) بتدرّج يحاكي خلفية استوديو،
 * ويترك الثلث المناسب هادئاً كما يفعل البرومبت الحقيقي.
 */
function gradientPng(width: number, height: number): string {
  const raw: number[] = [];
  for (let y = 0; y < height; y++) {
    raw.push(0); // filter byte: None
    const t = y / Math.max(1, height - 1);
    for (let x = 0; x < width; x++) {
      const u = x / Math.max(1, width - 1);
      // تدرّج كحلي إلى كورالي — نفس هوية التطبيق
      const shade = 0.55 + 0.45 * (1 - t);
      raw.push(
        Math.round((31 + 218 * u * (1 - t)) * shade),
        Math.round((42 + 55 * u * (1 - t)) * shade),
        Math.round((94 + 9 * u) * shade),
      );
    }
  }
  return buildPng(width, height, Buffer.from(raw));
}

function buildPng(width: number, height: number, rawScanlines: Buffer): string {
  const chunks: Buffer[] = [];
  chunks.push(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // color type: truecolor
  chunks.push(pngChunk('IHDR', ihdr));
  chunks.push(pngChunk('IDAT', zlibDeflate(rawScanlines)));
  chunks.push(pngChunk('IEND', Buffer.alloc(0)));

  return Buffer.concat(chunks).toString('base64');
}

function pngChunk(type: string, data: Buffer): Buffer {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crc]);
}

function zlibDeflate(data: Buffer): Buffer {
  // deflateSync من المكتبة القياسية — بلا تبعيات خارجية
  return zlib.deflateSync(data, { level: 6 });
}

let CRC_TABLE: number[] | null = null;
function crc32(buf: Buffer): number {
  if (!CRC_TABLE) {
    CRC_TABLE = [];
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      CRC_TABLE[n] = c >>> 0;
    }
  }
  let crc = 0xffffffff;
  for (const byte of buf) crc = (CRC_TABLE[(crc ^ byte) & 0xff] as number) ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}
