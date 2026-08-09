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
  const allowed = new Set(allowedOrigins.map((o) => o.replace(/\/$/, '')));

  return (req: Request, res: Response, next: NextFunction) => {
    const origin = req.header('origin');

    if (origin) {
      const normalized = origin.replace(/\/$/, '');
      if (allowAll || allowed.has(normalized)) {
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

/** يقرأ الأصول المسموح بها من البيئة، وافتراضها منافذ التطوير المحلية. */
export function allowedOriginsFromEnv(env = process.env): string[] {
  const raw = env.ALLOWED_ORIGINS?.trim();
  if (raw) {
    return raw
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);
  }
  return ['http://localhost:8877', 'http://127.0.0.1:8877', 'http://localhost:5000'];
}
