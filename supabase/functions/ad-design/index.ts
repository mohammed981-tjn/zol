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

/** ترويسات CORS: التطبيق يعمل على الويب أيضًا، وبلا هذه لا يولّد فيه
 *  شيء — والمتصفّح يرفض قبل أن يصل النداء إلى الدالّة. */
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-gemini-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), {
    status: s,
    headers: { "Content-Type": "application/json", ...CORS },
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

/** بعض النماذج تلفّ JSON بسياج ```json رغم الطلب الصريح.
 *
 *  والمعاد `unknown` لا `Record`: المخرَج قد يكون **مصفوفة** في أعلى
 *  المستوى، وتسميتها كائنًا تُخفي ذلك عن المترجم فيمرّ التعامل معها
 *  كائنًا بلا إنذار — وهو ما كان يقع. */
function parseJson(text: string): unknown {
  try { return JSON.parse(text); } catch { /* تحت */ }
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) { try { return JSON.parse(fenced[1]); } catch { /* تحت */ } }
  // القوس المعقوف **والمربّع**: آخر ملاذٍ كان يلتقط الكائن وحده، فنصٌّ
  // حول مصفوفة يسقط كلّه.
  const braced = text.match(/[[{][\s\S]*[\]}]/);
  if (braced) { try { return JSON.parse(braced[0]); } catch { /* تحت */ } }
  return {};
}

/** عدّاد نداءات خلال اليوم الماضي — للتاجر أو للمنصّة كلّها. */
async function usedSince(filter: string): Promise<number | null> {
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });

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

  // الهوية شرط لا خيار.
  //
  // `verify_jwt` مطفأة على هذه الدالّة كبقيّة دوالّ المشروع، فمن يعرف
  // رابطها ينفق مفتاحنا بلا حدّ. واشتراط `merchant_id` لا يمنع تزويرًا
  // (لا نتحقّق من الرمز بعد)، لكنه يجعل الإنفاق **محسوبًا على أحد**
  // ويُفعّل البوّابتين أدناه.
  const merchant = (b.merchant_id ?? "").trim();
  if (!merchant) return json({ ok: false, error: "merchant_required" }, 401);

  const PER_MERCHANT = Number(Deno.env.get("DAILY_DESIGN_LIMIT") ?? "40");
  const GLOBAL = Number(Deno.env.get("DAILY_DESIGN_LIMIT_GLOBAL") ?? "600");

  // بوّابتان لا واحدة. الأولى تمنع تاجرًا واحدًا من استنزاف نفسه،
  // والثانية تمنع من يزوّر هويّات كثيرة من استنزاف المفتاح كلّه — وهي
  // السقف الحقيقي على الخسارة اليومية.
  const mineUsed = await usedSince(
    `merchant_id=eq.${encodeURIComponent(merchant)}&prompt_key=eq.ad_design_system`,
  );
  if (mineUsed !== null && mineUsed >= PER_MERCHANT) {
    return json(
      { ok: false, error: "daily_quota", limit: PER_MERCHANT, used: mineUsed },
      429,
    );
  }

  const allUsed = await usedSince("prompt_key=eq.ad_design_system");
  if (allUsed !== null && allUsed >= GLOBAL) {
    return json({ ok: false, error: "service_busy", limit: GLOBAL }, 429);
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

    // ثلاثة أشكال مقبولة: مصفوفة في أعلى المستوى، أو مصفوفة تحت
    // "designs"، أو مواصفة واحدة. النموذج يخلط بينها، ورفضُ الصالح لأن
    // غلافه اختلف إهدار.
    //
    // والشكل الأوّل كان مرفوضًا وهو **أطبعها**: حين يُطلب أكثر من تخطيط
    // يردّ النموذج مصفوفةً عاريةً `[{…},{…}]` كما يفعل أيّ أحد طُلبت
    // منه قائمة. و`count` الافتراضي في التطبيق **اثنان**، فكان هذا
    // مسار الأغلبية لا حالةً نادرة: يسقط النداء بـ‎502‎، ويقرأ التاجر
    // «تعذّر»، ويُنفَق نداء النموذج كاملًا على مخرَجٍ صالحٍ رميناه.
    //
    // وقد أخفاه المترجم: `parseJson` كان يَعِد بـ`Record<string,
    // unknown>` فمرّت المصفوفة كائنًا بلا إنذار، و`parsed.designs`
    // عليها `undefined` بلا خطأ. راجع تعليق `parseJson`.
    const obj = (parsed ?? {}) as Record<string, unknown>;
    const raw: unknown[] = Array.isArray(parsed)
      ? parsed
      : Array.isArray(obj.designs)
      ? obj.designs as unknown[]
      : (obj.elements ? [obj] : []);

    // الشكل يُفحص هنا لا في العميل وحده: مصفوفة فيها عنصر بلا
    // `elements` كانت تمرّ بـ`ok:true` فيرى التاجر تصميمًا فارغًا
    // ويظنّ التطبيق معطّلًا، ولا يظهر في السجل أن شيئًا أخفق.
    const specs = raw.filter((d) => {
      const o = d as Record<string, unknown>;
      return o && Array.isArray(o.elements) && o.elements.length > 0;
    });

    if (!specs.length) {
      await logRow({
        merchant, prompt: brief, model: r.model, p,
        tin: r.tin, tout: r.tout, ms: Date.now() - t0,
        status: "error", output: r.text.slice(0, 2000),
      });
      return json({ ok: false, step: "designer", model: r.model, raw: r.text.slice(0, 400) }, 502);
    }

    const cost = +(r.tin / 1e6 * IN_PER_M + r.tout / 1e6 * OUT_PER_M).toFixed(6);

    await logRow({
      merchant, prompt: brief, model: r.model, p,
      tin: r.tin, tout: r.tout, ms: Date.now() - t0,
      status: "ok", output: JSON.stringify(specs).slice(0, 8000), cost,
    });

    return json({
      ok: true,
      model: r.model,
      ms: Date.now() - t0,
      designs: specs,
    });
  } catch (e) {
    // العطل يُسجَّل أيضًا. صفوف النجاح وحدها تجعل لوحة الإدارة تقول إن
    // كل شيء بخير بينما نصف النداءات تسقط.
    await logRow({
      merchant, prompt: wish.slice(0, 500), model: "-", p: null,
      tin: 0, tout: 0, ms: Date.now() - t0,
      status: "error", output: String(e).slice(0, 500),
    });
    return json({ ok: false, error: String(e).slice(0, 300) }, 502);
  }
});

/** كتابة صفّ في سجل التوليد. لا تُسقط الردّ أبدًا: التاجر ينتظر تصميمه،
 *  وفشلُ الكتابة في جدول تحليلات لا يجوز أن يحرمه إياه. */
async function logRow(a: {
  merchant: string;
  prompt: string;
  model: string;
  p: { version: number } | null;
  tin: number;
  tout: number;
  ms: number;
  status: string;
  output: string;
  cost?: number;
}) {
  try {
    await rest("generation_logs", {
      method: "POST",
      body: JSON.stringify({
        merchant_id: a.merchant,
        prompt: a.prompt,
        output_text: a.output,
        model: a.model,
        provider: "google",
        prompt_key: "ad_design_system",
        prompt_version: a.p?.version ?? null,
        tokens_in: a.tin,
        tokens_out: a.tout,
        cost_usd: a.cost ?? 0,
        latency_ms: a.ms,
        status: a.status,
      }),
    });
  } catch { /* تجاهَل */ }
}
