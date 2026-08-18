import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * ad-design — النموذج يُخرج **تخطيطًا** لا نصًّا.
 *
 * `ad-copy` يعيد عنوانًا ووصفًا وهاشتاقات، ثم يختار التطبيق واحدًا من
 * أحد عشر تخطيطًا مكتوبًا في Dart. فالذكاء يملأ فراغات ولا يُركّب
 * تكوينًا — ومهما حُسّنت القوالب بقي العدد أحد عشر.
 *
 * هنا يُخرج مواصفة (`DesignSpec`): عناصر بأدوار وإحداثيات كسريّة وألوان
 * كأدوار. والتطبيق يمرّرها على `SpecDoctor` ثم يرسمها بـ`SpecRenderer`.
 *
 * ولا نثق بمخرَجه: الفحص كلّه في العميل حيث تُعرف اللوحة اللونية الفعلية
 * للتاجر ونِسَب صيغته. الخادم يُقيّد بالبرومبت، والعميل يقيس ويُصلح.
 */

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const G = "https://generativelanguage.googleapis.com/v1beta/models";

const MODEL = Deno.env.get("AI_TEXT_MODEL") ?? "gemini-3.5-flash";
/** حصة جيميناي عشرون نداءً في الدقيقة **لكل نموذج**، فللخفيف حصته
 *  المستقلّة: ازدحام الأول يعني تأخّرًا ثوانيَ لا سقوطًا. */
const FALLBACK_MODEL =
  Deno.env.get("AI_TEXT_MODEL_FALLBACK") ?? "gemini-3.1-flash-lite";

const IN_PER_M = Number(Deno.env.get("AI_PRICE_IN") ?? "0.30");
const OUT_PER_M = Number(Deno.env.get("AI_PRICE_OUT") ?? "2.50");

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), {
    status: s,
    headers: { "Content-Type": "application/json" },
  });

const rest = (path: string, init: RequestInit = {}) =>
  fetch(`${SB_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: SB_KEY,
      Authorization: `Bearer ${SB_KEY}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });

async function getPrompt(key: string) {
  const r = await rest(
    `prompts?key=eq.${key}&is_active=eq.true&select=content,version`,
  );
  const rows = await r.json();
  if (!Array.isArray(rows) || !rows.length) throw new Error(`prompt_missing:${key}`);
  return rows[0] as { content: string; version: number };
}

async function gemini(key: string, system: string, user: string) {
  const t0 = Date.now();
  const models = [MODEL, MODEL, FALLBACK_MODEL];
  let lastErr = "";
  for (let attempt = 0; attempt < models.length; attempt++) {
    if (attempt > 0) await new Promise((r) => setTimeout(r, 1500 * attempt));
    const m = models[attempt];
    const r = await fetch(`${G}/${m}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: system }] },
        contents: [{ role: "user", parts: [{ text: user }] }],
        // حرارة أقلّ من التي يستعملها كاتب النصّ: التخطيط بنية لا
        // إبداع لغوي، والحرارة العالية تُخرج إحداثيات عشوائية.
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0.75,
        },
      }),
    });
    const j = await r.json();
    if (r.ok) {
      const text = j?.candidates?.[0]?.content?.parts
        ?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
      const u = j?.usageMetadata ?? {};
      return {
        text, ms: Date.now() - t0, model: m,
        tin: u.promptTokenCount ?? 0,
        tout: (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0),
      };
    }
    lastErr = `gemini_${r.status}:${j?.error?.message ?? "unknown"}`;
    if (r.status !== 429 && r.status !== 503) break;
  }
  throw new Error(lastErr);
}

/** بعض النماذج تلفّ JSON بسياج ```json رغم الطلب الصريح. */
function parseJson(text: string): Record<string, unknown> {
  try { return JSON.parse(text); } catch { /* تحت */ }
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) { try { return JSON.parse(fenced[1]); } catch { /* تحت */ } }
  const braced = text.match(/\{[\s\S]*\}/);
  if (braced) { try { return JSON.parse(braced[0]); } catch { /* تحت */ } }
  return {};
}

Deno.serve(async (req: Request) => {
  const key = req.headers.get("x-gemini-key") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!key) return json({ ok: false, error: "no_api_key" }, 400);

  let b: {
    merchant_id?: string;
    /** ما كتبه التاجر بحرّيته — قلب الميزة. */
    wish?: string;
    product?: string;
    format?: string;
    aspect?: number;
    tone?: string;
    brand_name?: string;
    has_image?: boolean;
    /** عدد التخطيطات المطلوبة (١ إلى ٤). */
    count?: number;
  };
  try { b = await req.json(); } catch { return json({ ok: false, error: "bad_json" }, 400); }

  const wish = (b.wish ?? "").trim();
  if (!wish && !b.product) {
    return json({ ok: false, error: "wish_or_product_required" }, 400);
  }

  const t0 = Date.now();
  try {
    const p = await getPrompt("ad_design_system");

    // النسبة تُذكر رقمًا لا اسمًا: النموذج لا يعرف كم عرض «رول أب»،
    // ولكنه يفهم أن ٠٫٤٢ لوحة طويلة جدًّا فيبني عليها.
    const brief = [
      `طلب التاجر: ${wish || b.product}`,
      b.product ? `المنتج: ${b.product}` : null,
      b.brand_name ? `العلامة: ${b.brand_name}` : null,
      b.tone ? `النبرة: ${b.tone}` : null,
      b.format ? `الصيغة: ${b.format}` : null,
      b.aspect ? `نسبة اللوحة (عرض÷ارتفاع): ${b.aspect.toFixed(3)}` : null,
      `صورة منتج متاحة: ${b.has_image ? "نعم" : "لا"}`,
    ].filter(Boolean).join("\n");

    const count = Math.min(Math.max(b.count ?? 1, 1), 4);
    const user = count === 1
      ? brief
      : `${brief}\n\nأخرج ${count} تخطيطات مختلفة التكوين في مصفوفة ` +
        `باسم "designs"، كل عنصر منها بالشكل المطلوب.`;

    const r = await gemini(key, p.content, user);
    const parsed = parseJson(r.text);

    // شكلان مقبولان: مواصفة واحدة، أو مصفوفة تحت "designs". النموذج
    // يخلط بينهما تحت الازدحام، ورفضُ الصالح لأن غلافه اختلف إهدار.
    const specs = Array.isArray(parsed.designs)
      ? parsed.designs as unknown[]
      : (parsed.elements ? [parsed] : []);

    if (!specs.length) {
      return json({ ok: false, step: "designer", model: r.model, raw: r.text.slice(0, 400) }, 502);
    }

    const cost = +(r.tin / 1e6 * IN_PER_M + r.tout / 1e6 * OUT_PER_M).toFixed(6);

    // السجلّ لا يُسقط الردّ: التاجر ينتظر تصميمه، وفشل الكتابة في جدول
    // تحليلات لا يجوز أن يحرمه إياه.
    if (b.merchant_id) {
      try {
        await rest("generation_logs", {
          method: "POST",
          body: JSON.stringify({
            merchant_id: b.merchant_id,
            prompt: brief,
            output_text: JSON.stringify(specs).slice(0, 8000),
            model: r.model, provider: "google",
            prompt_key: "ad_design_system", prompt_version: p.version,
            tokens_in: r.tin, tokens_out: r.tout, cost_usd: cost,
            latency_ms: Date.now() - t0, status: "ok",
          }),
        });
      } catch { /* تجاهَل: التحليلات ليست في مسار التاجر الحرج */ }
    }

    return json({
      ok: true,
      model: r.model,
      ms: Date.now() - t0,
      designs: specs,
    });
  } catch (e) {
    return json({ ok: false, error: String(e).slice(0, 300) }, 502);
  }
});
