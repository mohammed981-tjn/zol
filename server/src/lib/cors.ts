import type { NextFunction, Request, RequestHandler, Response } from 'express';

/**
 * CORS.
 *
 * تطبيق أندرويد وiOS لا يحتاج هذا، لكن نسخة الويب تحتاجه: المتصفح يحجب أي
 * طلب إلى أصل مختلف عن الأصل الذي حُمّلت منه الصفحة، ويسبقه بطلب preflight.
 *
 * قائمة أصول صريحة لا `*`: الأصل المسموح يُصرَّح في بيئة الخادم، فلا يستطيع
 * أي موقع آخر استهلاك حصتك من متصفح مستخدميه.
 */
export function cors(allowedOrigins: string[]): RequestHandler {
  const allowAll = allowedOrigins.includes('*');
  const allowLocal = allowedOrigins.includes('localhost:*');
  const allowed = new Set(allowedOrigins.map((o) => o.replace(/\/$/, '')));

  return (req: Request, res: Response, next: NextFunction) => {
    const origin = req.header('origin');

    if (origin) {
      const normalized = origin.replace(/\/$/, '');
      if (allowAll || allowed.has(normalized) || (allowLocal && isLocalhost(normalized))) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
      }
    }

    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.setHeader(
      'Access-Control-Allow-Headers',
      'content-type,x-account-id,x-account-plan',
    );
    res.setHeader('Access-Control-Max-Age', '86400');

    if (req.method === 'OPTIONS') {
      res.status(204).end();
      return;
    }
    next();
  };
}

/**
 * أصل محلي؟ (أي منفذ على localhost أو 127.0.0.1)
 *
 * لا يُقبل إلا حين تُدرَج `localhost:*` صراحةً. صفحة على جهاز المطوّر لا
 * تصل إلى منسّق إنتاجي، لأن المتصفح يمنع الخلط بين http وhttps أصلاً،
 * والأهم أن الإنتاج لا يضع هذه القيمة في ALLOWED_ORIGINS.
 */
function isLocalhost(origin: string): boolean {
  try {
    const { hostname } = new URL(origin);
    return hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1';
  } catch {
    return false;
  }
}

/**
 * يقرأ الأصول المسموح بها من البيئة.
 *
 * الافتراض `localhost:*` لا منفذاً بعينه: `flutter run -d chrome` يختار
 * منفذاً عشوائياً في كل تشغيل، فقائمة بمنفذ ثابت كانت تُسقط الطلب بخطأ
 * CORS مبهم ما لم يُمرَّر --web-port يدوياً في كل مرة. الإنتاج يضبط
 * ALLOWED_ORIGINS بأصوله الصريحة فيسقط هذا التساهل تلقائياً.
 */
export function allowedOriginsFromEnv(env = process.env): string[] {
  const raw = env.ALLOWED_ORIGINS?.trim();
  if (raw) {
    return raw
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);
  }
  return ['localhost:*'];
}
