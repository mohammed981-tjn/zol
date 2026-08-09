/**
 * العدّاد والحدود.
 *
 * هذا هو الضابط المباشر للخطر R1 في دراسة الجدوى: تكلفة معاينة غير محدودة.
 * القاعدة الحاكمة: الحد يُنفَّذ هنا على الخادم، ولا يُترك للواجهة أبداً —
 * لأن الواجهة قابلة للتعديل والخادم هو من يدفع الفاتورة.
 *
 * التخزين خلف واجهة مجرّدة: النسخة الحالية في الذاكرة (للتطوير)، ويُستبدل
 * بـ Firestore أو Redis في الإنتاج بلا تغيير في منطق الاستدعاء.
 */

export type PlanId = 'free' | 'pro';

export interface PlanLimits {
  /** أقصى عدد معاينات في اليوم */
  previewsPerDay: number;
  /** هل يُسمح بالعمليات المكلفة (الفيديو) لهذه الخطة؟ */
  allowExpensiveRender: boolean;
}

/**
 * الحدود مستمدة من حساب اقتصاديات الوحدة في الدراسة:
 * معاينة نص + صورة ≈ ‎$0.05، فسقف 5 معاينات يومياً للمجاني يحدّ التعرّض
 * بـ‎$7.5 شهرياً لكل مستخدم مجاني بدل انفتاح غير محسوب.
 */
export const PLANS: Record<PlanId, PlanLimits> = {
  free: { previewsPerDay: 5, allowExpensiveRender: false },
  pro: { previewsPerDay: 60, allowExpensiveRender: true },
};

export interface UsageStore {
  /** يزيد العدّاد ويُعيد القيمة بعد الزيادة. */
  increment(key: string, ttlSeconds: number): Promise<number>;
  /** يقرأ العدّاد الحالي بلا زيادة. */
  peek(key: string): Promise<number>;
}

export class InMemoryUsageStore implements UsageStore {
  private readonly counters = new Map<string, { value: number; expiresAt: number }>();

  async increment(key: string, ttlSeconds: number): Promise<number> {
    const now = Date.now();
    const existing = this.counters.get(key);
    if (!existing || existing.expiresAt <= now) {
      this.counters.set(key, { value: 1, expiresAt: now + ttlSeconds * 1000 });
      return 1;
    }
    existing.value += 1;
    return existing.value;
  }

  async peek(key: string): Promise<number> {
    const entry = this.counters.get(key);
    if (!entry || entry.expiresAt <= Date.now()) return 0;
    return entry.value;
  }
}

export class QuotaExceededError extends Error {
  constructor(
    readonly limit: number,
    readonly used: number,
    readonly plan: PlanId,
  ) {
    super(`تجاوزت حدّ خطتك: ${used} من ${limit} معاينة اليوم`);
    this.name = 'QuotaExceededError';
  }
}

export class Metering {
  constructor(private readonly store: UsageStore) {}

  /** مفتاح يومي لكل حساب — يُصفَّر تلقائياً بانتهاء صلاحيته. */
  private dayKey(accountId: string, date = new Date()): string {
    const day = date.toISOString().slice(0, 10);
    return `previews:${accountId}:${day}`;
  }

  /**
   * يحجز معاينة واحدة قبل أي استدعاء مكلف.
   * يرفع QuotaExceededError إذا تجاوز الحساب حدّه — والاستدعاء لا يحدث أصلاً.
   */
  async reservePreview(accountId: string, plan: PlanId): Promise<{ used: number; limit: number }> {
    const limits = PLANS[plan];
    const key = this.dayKey(accountId);

    const current = await this.store.peek(key);
    if (current >= limits.previewsPerDay) {
      throw new QuotaExceededError(limits.previewsPerDay, current, plan);
    }

    const used = await this.store.increment(key, 60 * 60 * 24);
    return { used, limit: limits.previewsPerDay };
  }

  async status(accountId: string, plan: PlanId): Promise<{ used: number; limit: number; remaining: number }> {
    const limit = PLANS[plan].previewsPerDay;
    const used = await this.store.peek(this.dayKey(accountId));
    return { used, limit, remaining: Math.max(0, limit - used) };
  }

  /** بوابة الالتزام: العمليات المكلفة ممنوعة على الخطة المجانية. */
  assertCanRenderExpensive(plan: PlanId): void {
    if (!PLANS[plan].allowExpensiveRender) {
      throw new QuotaExceededError(0, 0, plan);
    }
  }
}
