import assert from 'node:assert/strict';
import { describe, it, before, after } from 'node:test';
import type { AddressInfo } from 'node:net';
import type { Server } from 'node:http';

import { createApp } from '../src/app.ts';
import { InMemoryUsageStore, PLANS } from '../src/lib/metering.ts';
import { MockImageProvider, MockTextProvider } from '../src/providers/mock.ts';
import type { ImageProvider } from '../src/providers/types.ts';

let server: Server;
let base: string;
/** يعدّ كم مرة استُدعي مزوّد الصور فعلاً — جوهر اختبار الحدّ. */
let imageCalls = 0;

const countingImageProvider: ImageProvider = {
  name: 'counting',
  async generate(input) {
    imageCalls += 1;
    return new MockImageProvider().generate(input);
  },
};

before(async () => {
  const app = createApp({
    textProvider: new MockTextProvider(),
    imageProvider: countingImageProvider,
    usageStore: new InMemoryUsageStore(),
  });
  server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(() => {
  server.close();
});


/** fetch().json() يُعيد unknown في TS الحديث؛ هذا المساعد يُبقي الاختبارات مقروءة. */
async function readJson(res: Response): Promise<Record<string, any>> {
  return (await res.json()) as Record<string, any>;
}

const validBody = {
  productName: 'قهوة مختصة',
  productDescription: 'حبوب إثيوبية محمّصة محلياً',
  tone: 'عاطفي',
  platform: 'إنستغرام',
};

function post(path: string, body: unknown, headers: Record<string, string> = {}) {
  return fetch(`${base}${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

describe('GET /health', () => {
  it('يبلّغ عن المزوّدين المستخدمين', async () => {
    const res = await fetch(`${base}/health`);
    assert.equal(res.status, 200);
    const json = await readJson(res);
    assert.equal(json.ok, true);
    assert.equal(json.textProvider, 'mock');
  });
});

describe('POST /api/generate/preview', () => {
  it('يُعيد نصاً وصورة وحصة', async () => {
    const res = await post('/api/generate/preview', validBody, { 'x-account-id': 'acc-preview' });
    assert.equal(res.status, 200);
    const json = await readJson(res);

    assert.equal(json.copy.variants.length, 3);
    assert.ok(json.image.base64.length > 100);
    assert.equal(json.image.aspectRatio, '4:5');
    assert.equal(json.quota.limit, PLANS.free.previewsPerDay);
    assert.equal(
      json.textOverlayRequired,
      true,
      'الخادم يجب أن يخبر الواجهة أن النص العربي يُركَّب في التطبيق',
    );
  });

  it('يمكن تخطي الصورة لتقليل التكلفة', async () => {
    const before = imageCalls;
    const res = await post(
      '/api/generate/preview',
      { ...validBody, includeImage: false },
      { 'x-account-id': 'acc-noimage' },
    );
    assert.equal(res.status, 200);
    const json = await readJson(res);
    assert.equal(json.image, null);
    assert.equal(imageCalls, before, 'لا يجوز استدعاء مزوّد الصور عند includeImage=false');
  });

  it('يرفض طلباً ناقصاً برسالة مفهومة', async () => {
    const res = await post('/api/generate/preview', { productName: 'x' }, {});
    assert.equal(res.status, 400);
    const json = await readJson(res);
    assert.equal(json.error, 'invalid_request');
    assert.ok(Array.isArray(json.issues) && json.issues.length > 0);
  });

  it('يرفض نبرة غير معروفة', async () => {
    const res = await post('/api/generate/preview', { ...validBody, tone: 'ساخر' }, {});
    assert.equal(res.status, 400);
  });
});

describe('حدّ الاستخدام — الضابط الحرج', () => {
  it('يمنع التوليد بعد استهلاك الحد، ولا يستدعي المزوّد المكلف', async () => {
    const account = 'acc-quota';
    const limit = PLANS.free.previewsPerDay;

    for (let i = 0; i < limit; i++) {
      const ok = await post('/api/generate/preview', validBody, { 'x-account-id': account });
      assert.equal(ok.status, 200, `الطلب ${i + 1} كان يجب أن ينجح`);
    }

    const callsBeforeBlocked = imageCalls;
    const blocked = await post('/api/generate/preview', validBody, { 'x-account-id': account });

    assert.equal(blocked.status, 429);
    const json = await readJson(blocked);
    assert.equal(json.error, 'quota_exceeded');
    assert.equal(json.plan, 'free');
    assert.equal(
      imageCalls,
      callsBeforeBlocked,
      'لا يجوز استدعاء مزوّد الصور بعد تجاوز الحد — التكلفة تُدفع لحظة التوليد',
    );
  });

  it('حساب آخر لا يتأثر بحدّ حساب سابق', async () => {
    const res = await post('/api/generate/preview', validBody, { 'x-account-id': 'acc-fresh' });
    assert.equal(res.status, 200);
  });

  it('خطة pro تمنح حداً أعلى', async () => {
    const res = await fetch(`${base}/api/usage`, {
      headers: { 'x-account-id': 'acc-pro', 'x-account-plan': 'pro' },
    });
    const json = await readJson(res);
    assert.equal(json.plan, 'pro');
    assert.equal(json.limit, PLANS.pro.previewsPerDay);
    assert.ok(json.limit > PLANS.free.previewsPerDay);
  });
});

describe('GET /api/options', () => {
  it('يعرض النبرات والمنصات للواجهة', async () => {
    const res = await fetch(`${base}/api/options`);
    const json = await readJson(res);
    assert.ok(json.tones.includes('حماسي'));
    assert.ok(json.platforms.includes('سناب شات'));
    assert.equal(json.plans.free.allowExpensiveRender, false, 'الفيديو ممنوع على المجاني');
  });
});
