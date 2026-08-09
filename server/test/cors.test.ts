import assert from 'node:assert/strict';
import { describe, it, before, after } from 'node:test';
import type { AddressInfo } from 'node:net';
import type { Server } from 'node:http';

import { createApp } from '../src/app.ts';
import { allowedOriginsFromEnv } from '../src/lib/cors.ts';
import { MockImageProvider, MockTextProvider } from '../src/providers/mock.ts';

/**
 * هذه الاختبارات موجودة لأن غياب CORS عطّل نسخة الويب فعلاً عند أول تشغيل
 * حقيقي: التطبيق على منفذ والمنسّق على آخر، فحجب المتصفح الطلب.
 */

let server: Server;
let base: string;
const ALLOWED = 'http://localhost:8877';

before(async () => {
  const app = createApp({
    textProvider: new MockTextProvider(),
    imageProvider: new MockImageProvider(),
    allowedOrigins: [ALLOWED],
  });
  server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});

after(() => server.close());

describe('CORS', () => {
  it('يجيب على preflight بـ204 وبالترويسات المطلوبة', async () => {
    const res = await fetch(`${base}/api/generate/preview`, {
      method: 'OPTIONS',
      headers: {
        origin: ALLOWED,
        'access-control-request-method': 'POST',
        'access-control-request-headers': 'content-type,x-account-id',
      },
    });

    assert.equal(res.status, 204);
    assert.equal(res.headers.get('access-control-allow-origin'), ALLOWED);

    const methods = res.headers.get('access-control-allow-methods') ?? '';
    assert.ok(methods.includes('POST'));

    const headers = (res.headers.get('access-control-allow-headers') ?? '').toLowerCase();
    for (const h of ['content-type', 'x-account-id', 'x-account-plan']) {
      assert.ok(headers.includes(h), `يجب السماح بالترويسة ${h}`);
    }
  });

  it('يسمح للأصل المصرَّح به في الردود العادية', async () => {
    const res = await fetch(`${base}/health`, { headers: { origin: ALLOWED } });
    assert.equal(res.headers.get('access-control-allow-origin'), ALLOWED);
    assert.equal(res.headers.get('vary'), 'Origin');
  });

  it('لا يمنح ترويسة السماح لأصل غير مصرَّح به', async () => {
    const res = await fetch(`${base}/health`, {
      headers: { origin: 'https://attacker.example' },
    });
    assert.equal(res.status, 200);
    assert.equal(
      res.headers.get('access-control-allow-origin'),
      null,
      'أصل غريب لا يجوز أن يحصل على إذن استهلاك حصة المستخدم',
    );
  });
});

describe('allowedOriginsFromEnv', () => {
  it('يقرأ قائمة مفصولة بفواصل', () => {
    const list = allowedOriginsFromEnv({
      ALLOWED_ORIGINS: 'https://a.com, https://b.com',
    } as NodeJS.ProcessEnv);
    assert.deepEqual(list, ['https://a.com', 'https://b.com']);
  });

  it('يعود لمنافذ التطوير عند غياب الإعداد', () => {
    const list = allowedOriginsFromEnv({} as NodeJS.ProcessEnv);
    assert.ok(list.some((o) => o.includes('localhost')));
  });
});
