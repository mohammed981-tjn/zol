import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { clampToWords, extractJson, generateCopy, generateImage } from '../src/lib/generate.ts';
import { buildImagePrompt, IMAGE_NEGATIVE_PROMPT } from '../src/promptbook/image.ts';
import { buildCopyPrompt } from '../src/promptbook/copy.ts';
import { MockImageProvider, MockTextProvider } from '../src/providers/mock.ts';
import type { TextProvider } from '../src/providers/types.ts';

const brief = {
  productName: 'عطر عود',
  tone: 'حماسي' as const,
  platform: 'إنستغرام' as const,
};

describe('extractJson', () => {
  it('يقرأ JSON نظيفاً', () => {
    assert.deepEqual(extractJson('{"a":1}'), { a: 1 });
  });

  it('يقرأ JSON محاطاً بأسوار برمجية', () => {
    assert.deepEqual(extractJson('```json\n{"a":2}\n```'), { a: 2 });
  });

  it('يقرأ JSON مسبوقاً بجملة تمهيدية', () => {
    assert.deepEqual(extractJson('تفضل الناتج:\n{"a":3}\nانتهى'), { a: 3 });
  });

  it('يفشل بوضوح عند رد غير صالح', () => {
    assert.throws(() => extractJson('لا يوجد كائن هنا'), /JSON/);
  });
});

describe('clampToWords', () => {
  it('لا يقصّ نصاً أقصر من الحد', () => {
    assert.equal(clampToWords('نص قصير', 50), 'نص قصير');
  });

  it('يقصّ عند مسافة لا في منتصف كلمة', () => {
    const out = clampToWords('كلمة واحدة وكلمة ثانية وكلمة ثالثة طويلة', 20);
    assert.ok(out.length <= 20);
    assert.ok(!out.endsWith(' '));
    // آخر كلمة يجب أن تكون كاملة
    assert.ok('كلمة واحدة وكلمة ثانية وكلمة ثالثة طويلة'.includes(out));
  });
});

describe('برومبت الصورة', () => {
  it('يمنع أي نص داخل الصورة صراحةً', () => {
    const prompt = buildImagePrompt(brief);
    for (const forbidden of ['no text', 'no letters', 'no words', 'no typography']) {
      assert.ok(prompt.includes(forbidden), `البرومبت يجب أن يمنع: ${forbidden}`);
    }
  });

  it('يمنع الخط العربي في البرومبت السلبي', () => {
    assert.ok(IMAGE_NEGATIVE_PROMPT.includes('arabic script'));
  });

  it('يترك مساحة هادئة تناسب نسبة المنصة', () => {
    assert.ok(buildImagePrompt({ ...brief, platform: 'تيك توك' }).includes('empty space'));
  });
});

describe('برومبت النص', () => {
  it('يضمّن النبرة والمنصة وحدودهما', () => {
    const prompt = buildCopyPrompt(brief);
    assert.ok(prompt.includes('حماسي'));
    assert.ok(prompt.includes('إنستغرام'));
    assert.ok(/حتى \d+ حرفاً/.test(prompt));
  });
});

describe('generateCopy', () => {
  it('يُنتج ثلاث صيغ ويطبّق النقد', async () => {
    const result = await generateCopy(new MockTextProvider(), brief);
    assert.equal(result.variants.length, 3);
    assert.equal(result.critiqued, true);
    assert.ok(result.bestIndex >= 0 && result.bestIndex < 3);
    for (const v of result.variants) {
      assert.ok(v.headline.length > 0);
      assert.ok(v.body.length > 0);
      assert.ok(v.hashtags.length > 0);
    }
  });

  it('يحترم حد أحرف المنصة', async () => {
    const result = await generateCopy(new MockTextProvider(), { ...brief, platform: 'سناب شات' });
    for (const v of result.variants) {
      assert.ok(v.headline.length <= 28, `العنوان تجاوز الحد: ${v.headline.length}`);
      assert.ok(v.body.length <= 120, `النص تجاوز الحد: ${v.body.length}`);
    }
  });

  it('يسلّم الصيغ حتى لو فشل النقد', async () => {
    let call = 0;
    const flaky: TextProvider = {
      name: 'flaky',
      async complete(input) {
        call += 1;
        if (call === 1) return new MockTextProvider().complete(input);
        throw new Error('النقد تعطّل');
      },
    };
    const result = await generateCopy(flaky, brief);
    assert.equal(result.variants.length, 3);
    assert.equal(result.critiqued, false, 'يجب الإبلاغ بأن النقد لم يجرِ');
  });

  it('يرفض رداً بلا صيغ صالحة', async () => {
    const empty: TextProvider = {
      name: 'empty',
      async complete() {
        return { text: JSON.stringify({ variants: [{ headline: '', body: '' }] }) };
      },
    };
    await assert.rejects(() => generateCopy(empty, brief), /صيغة صالحة/);
  });
});

describe('generateImage', () => {
  it('يُنتج PNG صالحاً بالنسبة الصحيحة', async () => {
    const out = await generateImage(new MockImageProvider(), brief);
    assert.equal(out.mimeType, 'image/png');
    assert.equal(out.aspectRatio, '4:5');

    const bytes = Buffer.from(out.imageBase64, 'base64');
    // توقيع PNG
    assert.deepEqual([...bytes.subarray(0, 8)], [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    // الأبعاد من ترويسة IHDR
    assert.equal(bytes.readUInt32BE(16), 864);
    assert.equal(bytes.readUInt32BE(20), 1080);
  });
});
