/**
 * بوابة الشركاء لتوليد الإعلانات.
 *
 * تصادق بمفتاح شريك، تفحص الحصة، ثم تمرّر إلى `ad-copy` كما هي — فلا
 * منطق توليد مكرَّر هنا، وأي تحسين على النموذج ينتفع به الشركاء بلا نشر
 * ثانٍ. الشريك لا يرى برومبتاً ولا مفتاح مزوّد ولا اسم نموذج إلا ما نعيده.
 *
 * النشر:
 *   supabase functions deploy ad-copy-partner --project-ref <ref> --no-verify-jwt
 *
 * `--no-verify-jwt` مقصود: الشريك يصادق بمفتاحه لا بـJWT مستخدم.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-partner-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body, null, 1), {
    status,
    headers: { "Content-Type": "application/json", ...CORS, ...extra },
  });
}

/** رموز HTTP صادقة: الحصة ليست خطأ عميل عامًّا بل 429 يعرف الشريك معناه. */
const STATUS: Record<string, number> = {
  invalid_key: 401,
  partner_suspended: 403,
  quota_exceeded: 429,
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

  const key = req.headers.get("x-partner-key")?.trim();
  if (!key) {
    return json({ ok: false, error: "missing_key", hint: "أرسل الترويسة X-Partner-Key" }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ ok: false, error: "invalid_json" }, 400);
  }

  const product = String(body.product ?? "").trim();
  if (!product) {
    return json({ ok: false, error: "missing_product", hint: "الحقل product مطلوب" }, 400);
  }

  // ١) المصادقة وفحص الحصة — نداء واحد على القاعدة.
  const authRes = await fetch(`${SB_URL}/rest/v1/rpc/partner_authenticate`, {
    method: "POST",
    headers: {
      apikey: SB_KEY,
      Authorization: `Bearer ${SB_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ p_key: key }),
  });

  if (!authRes.ok) {
    return json({ ok: false, error: "auth_unavailable" }, 503);
  }

  const auth = await authRes.json();
  if (!auth?.ok) {
    const code = String(auth?.error ?? "unauthorized");
    return json(
      {
        ok: false,
        error: code,
        ...(code === "quota_exceeded"
          ? { used: auth.used, quota: auth.quota }
          : {}),
      },
      STATUS[code] ?? 401,
    );
  }

  // ٢) التمرير إلى دالة التوليد القائمة بلا تغيير في سلوكها.
  const genRes = await fetch(`${SB_URL}/functions/v1/ad-copy`, {
    method: "POST",
    headers: {
      apikey: SB_KEY,
      Authorization: `Bearer ${SB_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      merchant_id: auth.merchant_id,
      product,
      platform: body.platform ?? "instagram",
      ...(body.brief && typeof body.brief === "object" ? { brief: body.brief } : {}),
    }),
  });

  const out = await genRes.json().catch(() => null);
  if (!genRes.ok || !out?.ok) {
    // تفصيلٌ يفيد الشريك: «generation_failed» وحدها لا تخبره أهو عطل
    // نموذج أم قاعدة، فيراسلنا ليكتشف ما كان يمكن أن يقرأه بنفسه.
    return json(
      {
        ok: false,
        error: "generation_failed",
        detail: out?.error ?? (out?.step ? `step:${out.step}` : null),
      },
      502,
    );
  }

  // ٣) رد نظيف: الصيغ ومقياس الحصة، بلا تسريب النموذج ولا التكلفة الداخلية.
  const remaining = auth.remaining < 0 ? null : Math.max(0, auth.remaining - 1);
  return json(
    {
      ok: true,
      partner: auth.name,
      generation_id: out.generation_id,
      variants: (out.variants ?? []).map((v: Record<string, unknown>) => ({
        angle: v.angle,
        headline: v.headline,
        body: v.body,
        cta: v.cta,
        hashtags: v.hashtags,
        score: v.score_total,
        rank: v.rank,
      })),
      quota: {
        limit: auth.quota < 0 ? null : auth.quota,
        used: auth.used + 1,
        remaining,
      },
    },
    200,
    {
      "X-Quota-Limit": auth.quota < 0 ? "unlimited" : String(auth.quota),
      "X-Quota-Remaining": remaining === null ? "unlimited" : String(remaining),
    },
  );
});
