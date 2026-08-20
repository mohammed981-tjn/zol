/**
 * حارس الدوالّ — الهوية والحصّة ومسار التخزين، في مكان واحد.
 *
 * كانت أربعٌ من دوالّنا السبع مكشوفة تمامًا: `ad-director` و`ad-image`
 * و`ad-compose` بلا هوية ولا حصّة، و`ad-copy` تكتب في `generation_logs`
 * وتظنّ ذلك حراسةً — والتسجيل يروي ما وقع ولا يمنعه. و`verify_jwt`
 * مطفأة على الجميع، فمن يعرف الرابط ينفق مفتاحنا. وأغلى المكشوفتين
 * اثنتان **تولّدان صورًا**.
 *
 * وثلاثتها كانت تفعل ما هو أسوأ من الإنفاق: تكتب في مخزنٍ عامّ بمسار
 * **يختاره المتصل** مع `x-upsert`، بمفتاح الخدمة. فمن ينادي الدالّة
 * يستبدل أيّ ملفّ في السطل — إعلان تاجرٍ منشور مثلًا — بما يولّده هو.
 * ودون أي نيّة سيّئة كان الاسم الافتراضي `ad.png` واحدًا للجميع، فتاجران
 * يولّدان في اللحظة نفسها يدهس أحدهما إعلان الآخر.
 *
 * ولماذا المشترك لا نسخة في كل دالّة: نسخُ البوّابة أربع مرّات يعني أن
 * إصلاحها لاحقًا يجب أن يُتذكَّر أربع مرّات — وقد نسينا `logo` في ثلاثة
 * نماذج من سبعة حين وُزّع مثله.
 *
 * (`ad-design` و`ad-magic` و`ad-copy-partner` محصّنة سلفًا بنسخها
 * الخاصّة، ولم تُحوَّل هنا: هي منشورة وتعمل، وتحويلُ ما يعمل بلا قدرة
 * على النشر والتجربة مقامرة. تحويلها خطوة تالية بعد أوّل نشر ناجح.)
 */

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

/** ترويسات CORS: التطبيق يعمل على الويب، وبلا هذه يرفض المتصفّح النداء
 *  قبل أن يصل إلى الدالّة أصلًا. */
export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-gemini-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), {
    status: s,
    headers: { "Content-Type": "application/json", ...CORS },
  });

export const rest = (path: string, init: RequestInit = {}) =>
  fetch(`${SB_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SB_KEY,
      Authorization: `Bearer ${SB_KEY}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });

/**
 * المعرّف الذي تُنسب إليه نداءات من لا هوية له.
 *
 * ‏UUID صفريّ لا كلمة «anon»: كل `merchant_id` في هذا المخطّط من نوع
 * `uuid`، وإدراج نصٍّ ليس معرّفًا يفشل — و[logRow] تبتلع فشلها عمدًا كي
 * لا تحرم التاجر مخرَجه. فتكون النتيجة أن صفوف المجهولين لا تُكتب، ولا
 * تُعدّ، ولا تُغلق بوّابتهم أبدًا: حراسةٌ موجودة في الشيفرة معدومة في
 * الأثر — وهي أسوأ من غيابها لأنها تُطمئن.
 */
export const ANON = "00000000-0000-0000-0000-000000000000";

export type Caller = { merchant: string; anonymous: boolean };

/**
 * من ينادي؟
 *
 * ولا نردّ ‎401‎ على من لا يعرّف بنفسه — وهذا خلاف ما فعلته `ad-design`،
 * والفرق مقصود: تلك وُلدت محصّنة فلا عميل قديم ينكسر بها، أمّا هذه فقد
 * شُحنت في نسخ مثبّتة على أجهزة لا ترسل `merchant_id` بعد. وردُّ ‎401‎
 * عليها يُعطّل الميزة عند كل من لم يحدّث — عقوبةٌ على المستخدم بذنب
 * لم يقترفه، لإصلاح تسريبٍ يكفي فيه سقفٌ.
 *
 * فالمجهول يُنسب إلى [ANON] ويأخذ حصّةً **صغيرة مشتركة**: يبقى الباب
 * مفتوحًا لمن حدّث ولمن لم يحدّث، وتبقى الخسارة اليومية محسوبة.
 */
export function identify(raw: unknown): Caller {
  const m = typeof raw === "string" ? raw.trim() : "";
  return m ? { merchant: m, anonymous: false } : { merchant: ANON, anonymous: true };
}

/** عدّاد نداءات خلال اليوم الماضي. `null` يعني تعذّر العدّ. */
export async function usedSince(filter: string): Promise<number | null> {
  const since = new Date(Date.now() - 86400000).toISOString();
  try {
    const r = await rest(
      `generation_logs?created_at=gte.${since}&${filter}&select=id`,
      { headers: { Prefer: "count=exact", Range: "0-0" } },
    );
    if (!r.ok) return null;
    return Number((r.headers.get("content-range") ?? "/0").split("/")[1] || "0");
  } catch {
    return null;
  }
}

/**
 * بوّابتا الحصّة. تعيد `Response` حين تُغلق، و`null` حين تُفتح.
 *
 * بوّابتان لا واحدة، ولكلٍّ عملها: الأولى تمنع منادِيًا واحدًا من استنزاف
 * نفسه، والثانية تمنع من يخترع هويّات كثيرة من استنزاف المفتاح كلّه —
 * وهي وحدها السقف الحقيقي على خسارة اليوم.
 *
 * والعدّ يقع على `generation_logs` بمفتاح [promptKey]، فلكل دالّة حصّتها
 * المستقلّة: ازدحام كاتب النصّ لا يُغلق مولّد الصور.
 */
export async function quotaGate(o: {
  caller: Caller;
  promptKey: string;
  perMerchant: number;
  perAnon: number;
  global: number;
}): Promise<Response | null> {
  const limit = o.caller.anonymous ? o.perAnon : o.perMerchant;
  const mine = await usedSince(
    `merchant_id=eq.${encodeURIComponent(o.caller.merchant)}` +
      `&prompt_key=eq.${encodeURIComponent(o.promptKey)}`,
  );
  if (mine !== null && mine >= limit) {
    return json(
      {
        ok: false,
        error: o.caller.anonymous ? "identify_to_continue" : "daily_quota",
        limit,
        used: mine,
      },
      429,
    );
  }

  const all = await usedSince(`prompt_key=eq.${encodeURIComponent(o.promptKey)}`);
  if (all !== null && all >= o.global) {
    return json({ ok: false, error: "service_busy", limit: o.global }, 429);
  }

  // المجهول يدفع **تذكرته أوّلًا**، والمعروف يُسجَّل بعد عمله.
  //
  // الفرق ليس تفضيلًا: العدّ كلّه يقع على صفوف `generation_logs`، فإن
  // تعذّرت كتابة صفّ المجهول — لأيّ سبب: نوع عمود، أو مفتاح أجنبي، أو
  // سياسة — بقي عدّاده صفرًا مهما نادى، وصارت حصّته لانهائية بينما تقول
  // الشيفرة إنها عشرون.
  //
  // فتُكتب تذكرته قبل الإنفاق: نجحت الكتابة فقد صار النداء محسوبًا،
  // وفشلت فنحن **لا نستطيع قياسه**، ومن لا يُقاس لا يُخدَم مجهولًا —
  // يُطلب منه أن يعرّف بنفسه. فشلٌ مُعلَن خيرٌ من حراسةٍ صامتة معطّلة.
  if (o.caller.anonymous) {
    const ticketed = await logRow({
      merchant: o.caller.merchant,
      promptKey: o.promptKey,
      prompt: "-",
      output: "-",
      model: "-",
      ms: 0,
      status: "start",
    });
    if (!ticketed) {
      return json({ ok: false, error: "identify_to_continue" }, 401);
    }
  }
  return null;
}

/**
 * مفتاح كائن التخزين — مُطهَّر ومنسوب إلى صاحبه.
 *
 * الاسم كان يصل من المتصل ويُركَّب في المسار كما هو: `../` تخرج من
 * السطل، والاسم المكرّر يدهس ملفّ غيره، والافتراضي الواحد يجعل كل
 * النداءات بلا اسم تتنازع ملفًّا واحدًا.
 *
 * فالحروف المسموحة وحدها تبقى، والمسار يبدأ بمُعرّف صاحبه، ولاحقةٌ
 * عشوائية تمنع الدهس. وثمنُها أن الملفّات لا تُستبدَل بل تتراكم —
 * وتنظيفها أهون من استرجاع إعلانٍ دُهس.
 */
export function objectKey(
  merchant: string,
  raw: unknown,
  fallback: string,
): string {
  const slug = (s: string) =>
    s.replace(/[^A-Za-z0-9_-]/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "")
      .slice(0, 48);
  const owner = slug(merchant) || ANON;
  const base = slug(typeof raw === "string" ? raw : "") || fallback;
  return `${owner}/${base}-${crypto.randomUUID().slice(0, 8)}.png`;
}

/**
 * تسجيل نتيجة النداء — ويتخطّى المجهول لأنه دفع تذكرته سلفًا.
 *
 * بلا هذا التخطّي يُحسب نداء المجهول مرّتين: تذكرةً قبل العمل وصفًّا
 * بعده، فتصير حصّته نصف ما يقوله الإعداد. والرقم الذي يكذب في الحصص
 * يُضبط لاحقًا بالتخمين حتى «يبدو صحيحًا» بدل أن يُصلَح.
 */
export const logCall = (
  caller: Caller,
  a: Omit<Parameters<typeof logRow>[0], "merchant">,
): Promise<boolean> =>
  caller.anonymous
    ? Promise.resolve(true)
    : logRow({ ...a, merchant: caller.merchant });

/**
 * كتابة صفّ في سجل التوليد — للنجاح **وللعطل**. تعيد هل نجحت الكتابة.
 *
 * والقيمة المعادة ليست زينة: [quotaGate] تبني عليها قرارها في المجهول.
 *
 * صفوف النجاح وحدها تجعل لوحة الإدارة تقول إن كل شيء بخير بينما نصف
 * النداءات تسقط. ولا تُسقط الردّ أبدًا: المنادي ينتظر مخرَجه، وفشلُ
 * الكتابة في جدول تحليلات لا يجوز أن يحرمه إيّاه.
 *
 * وهي أيضًا ما يعدّه [quotaGate]، فكل نداءٍ لا يُسجَّل نداءٌ لا يُحسب
 * على أحد — ولهذا يُسجَّل العطل: من يستنزف المفتاح بنداءات فاشلة ينفقه
 * كما ينفقه الناجح.
 */
export async function logRow(a: {
  merchant: string;
  promptKey: string;
  prompt: string;
  output: string;
  model: string;
  provider?: string;
  promptVersion?: number | null;
  tokensIn?: number;
  tokensOut?: number;
  costUsd?: number;
  ms: number;
  status: string;
}): Promise<boolean> {
  try {
    const r = await rest("generation_logs", {
      method: "POST",
      body: JSON.stringify({
        merchant_id: a.merchant,
        prompt: a.prompt.slice(0, 2000),
        output_text: a.output.slice(0, 8000),
        model: a.model,
        provider: a.provider ?? "google",
        prompt_key: a.promptKey,
        prompt_version: a.promptVersion ?? null,
        tokens_in: a.tokensIn ?? 0,
        tokens_out: a.tokensOut ?? 0,
        cost_usd: a.costUsd ?? 0,
        latency_ms: a.ms,
        status: a.status,
      }),
    });
    return r.ok;
  } catch {
    return false;
  }
}
