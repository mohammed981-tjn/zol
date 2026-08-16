import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const G = "https://generativelanguage.googleapis.com/v1beta/models";
const OR = "https://openrouter.ai/api/v1/chat/completions";

/** `google` (الافتراضي) أو `openrouter`. تبديله لا يحتاج نشراً. */
const PROVIDER = (Deno.env.get("AI_PROVIDER") ?? "google").toLowerCase();
const MODEL = Deno.env.get("AI_TEXT_MODEL") ?? "gemini-3.5-flash";
/** حصة جيميناي عشرون نداءً في الدقيقة لكل نموذج — ونموذج واحد بلا
 *  إعادة محاولة يعني أن أول ازدحام يُسقط توليد الشريك كاملًا. */
const FALLBACK_MODEL = Deno.env.get("AI_TEXT_MODEL_FALLBACK") ?? "gemini-3.1-flash-lite";

/**
 * سلسلة نماذج OpenRouter تُجرَّب بالترتيب حتى ينجح واحد.
 *
 * النماذج المجانية تُرجع 429 كثيراً حين تزدحم، فنموذج واحد يعني تعطّل
 * التوليد لا بطأه. القائمة تُضبط من متغيّر بيئة بلا نشر.
 */
const OR_MODELS = (Deno.env.get("OPENROUTER_MODELS") ??
  [
    "meta-llama/llama-3.3-70b-instruct:free",
    "qwen/qwen-2.5-72b-instruct:free",
    "google/gemma-3-27b-it:free",
    "mistralai/mistral-small-3.2-24b-instruct:free",
  ].join(","))
  .split(",").map((m) => m.trim()).filter(Boolean);

// سعر تقريبي لكل مليون رمز — يُضبط من متغير بيئة دون نشر
const IN_PER_M  = Number(Deno.env.get("AI_PRICE_IN")  ?? "0.30");
const OUT_PER_M = Number(Deno.env.get("AI_PRICE_OUT") ?? "2.50");

/** نموذج بلاحقة ‎:free‎ لا فاتورة له، فتسعيره بسعر مدفوع يفسد تقارير التكلفة. */
const isFree = (model: string) => model.endsWith(":free");

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

async function getPrompt(key: string): Promise<{ content: string; version: number }> {
  const r = await rest(`prompts?key=eq.${key}&is_active=eq.true&select=content,version`);
  const rows = await r.json();
  if (!Array.isArray(rows) || !rows.length) throw new Error(`prompt_missing:${key}`);
  return rows[0];
}

interface Completion {
  text: string;
  ms: number;
  tin: number;
  tout: number;
  model: string;
}

async function gemini(key: string, system: string, user: string): Promise<Completion> {
  const t0 = Date.now();
  // محاولتان على الأساسي ثم الخفيف: للخفيف حصة دقيقة مستقلة، فازدحام
  // الأول لم يعد يعني سقوط التوليد بل تأخّره ثوانيَ.
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
        generationConfig: { responseMimeType: "application/json", temperature: 1.0 },
      }),
    });
    const j = await r.json();
    if (r.ok) {
      const text = j?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
      const u = j?.usageMetadata ?? {};
      return {
        text, ms: Date.now() - t0, model: m,
        tin:  u.promptTokenCount ?? 0,
        tout: (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0),
      };
    }
    lastErr = `gemini_${r.status}:${j?.error?.message ?? "unknown"}`;
    if (r.status !== 429 && r.status !== 503) break;   // خطأ دائم — لا تكرر
  }
  throw new Error(lastErr);
}

/**
 * OpenRouter — بوّابة واحدة أمام عشرات النماذج بمفتاح واحد.
 *
 * يمرّ على OR_MODELS بالترتيب: أول نموذج يردّ نصاً صالحاً يفوز. النماذج
 * المجانية تزدحم وتُرجع 429، ومطالبة النموذج بـ JSON صِرف تُنفَّذ عبر
 * response_format لأن بعضها يلفّ الرد بسياج ```json.
 */
async function openrouter(key: string, system: string, user: string): Promise<Completion> {
  const t0 = Date.now();
  const failures: string[] = [];

  for (const model of OR_MODELS) {
    try {
      const r = await fetch(OR, {
        method: "POST",
        headers: {
          authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
          "HTTP-Referer": "https://github.com/mohammed981-tjn/zol",
          "X-Title": "Zol AdCraft",
        },
        body: JSON.stringify({
          model,
          temperature: 1.0,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
        }),
      });
      const j = await r.json();

      // OpenRouter قد يعيد 200 ومعه خطأ في الجسم (حصة نموذج مجاني)،
      // فلا يكفي فحص r.ok وحده.
      if (!r.ok || j?.error) {
        failures.push(`${model}:${r.status}:${j?.error?.message ?? "unknown"}`);
        continue;
      }

      const text = j?.choices?.[0]?.message?.content ?? "";
      if (!text.trim()) { failures.push(`${model}:empty`); continue; }

      const u = j?.usage ?? {};
      return {
        text, model, ms: Date.now() - t0,
        tin:  u.prompt_tokens ?? 0,
        tout: u.completion_tokens ?? 0,
      };
    } catch (e) {
      failures.push(`${model}:threw:${String(e).slice(0, 80)}`);
    }
  }

  throw new Error(`openrouter_all_failed:${failures.join(" | ").slice(0, 300)}`);
}

/** يوجّه إلى المزوّد المضبوط، ويعيد نفس الشكل مهما كان المزوّد. */
function complete(key: string, system: string, user: string): Promise<Completion> {
  return PROVIDER === "openrouter"
    ? openrouter(key, system, user)
    : gemini(key, system, user);
}

/** بعض النماذج تلفّ JSON بسياج ```json رغم الطلب الصريح. */
function parseJson(text: string): Record<string, unknown> {
  try { return JSON.parse(text); } catch { /* أسفل */ }
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (fenced) { try { return JSON.parse(fenced[1]); } catch { /* أسفل */ } }
  const braced = text.match(/\{[\s\S]*\}/);
  if (braced) { try { return JSON.parse(braced[0]); } catch { /* أسفل */ } }
  return {};
}

/**
 * استخراج المصفوفة مهما خان النموذج شكلَ الغلاف.
 *
 * شوهد حيًّا: النموذج تحت ازدحام الحصة يعيد `[{...}]` عارية بدل
 * `{"variants":[...]}` — فترتدّ صيغ سليمة المضمون تمامًا برمز
 * `generation_failed` في وجه الشريك. نقبل الشكلين، ملفوفين بنص أو
 * صريحين.
 */
function extractArray(raw: string, key: string): Array<Record<string, unknown>> {
  const as = raw.indexOf("["), ae = raw.lastIndexOf("]");
  const os = raw.indexOf("{");
  if (as >= 0 && ae > as && (os < 0 || as < os)) {
    try {
      const arr = JSON.parse(raw.slice(as, ae + 1));
      if (Array.isArray(arr)) return arr as Array<Record<string, unknown>>;
    } catch { /* جرّب الكائن */ }
  }
  const obj = parseJson(raw);
  return Array.isArray(obj?.[key])
    ? obj[key] as Array<Record<string, unknown>>
    : [];
}

/** أسماء المنصات كما يرسلها الشركاء (إنجليزية) ← كما يفهمها البرومبت. */
const PLATFORM_AR: Record<string, string> = {
  instagram: "إنستغرام",
  tiktok: "تيك توك",
  x: "إكس (تويتر)",
  twitter: "إكس (تويتر)",
  snapchat: "سناب شات",
};

const ANGLES = ["منفعة", "فضول", "عرض"];

Deno.serve(async (req: Request) => {
  const key = PROVIDER === "openrouter"
    ? (req.headers.get("x-openrouter-key") ?? Deno.env.get("OPENROUTER_API_KEY") ?? "")
    : (req.headers.get("x-gemini-key") ?? Deno.env.get("GEMINI_API_KEY") ?? "");
  if (!key) return json({ ok: false, error: "no_api_key", provider: PROVIDER }, 400);

  let b: {
    merchant_id: string; product: string; platform?: string;
    audience?: string; offer?: string; season?: string; dialect?: string;
    brand_name?: string; tone?: string;
    /** موجز حر من الشريك: {الفئة، الجمهور، العرض، النبرة} — الوثيقة
     *  تَعِد باستعماله، وكان يُستقبَل ثم يُهمَل بلا أثر في النص. */
    brief?: Record<string, unknown>;
  };
  try { b = await req.json(); } catch { return json({ ok: false, error: "bad_json" }, 400); }
  if (!b?.merchant_id || !b?.product) return json({ ok: false, error: "merchant_id_and_product_required" }, 400);

  const rawPlatform = b.platform ?? "سناب شات";
  const platform = PLATFORM_AR[rawPlatform.toLowerCase()] ?? rawPlatform;
  const t0 = Date.now();

  try {
    const writer = await getPrompt("ad_copy_system");
    const critic = await getPrompt("ad_critic_system");

    const brief = {
      العلامة: b.brand_name ?? null,
      المنتج: b.product,
      المنصة: platform,
      الجمهور: b.audience ?? null,
      العرض: b.offer ?? null,
      الموسم: b.season ?? null,
      اللهجة: b.dialect ?? "فصحى مبسّطة",
      النبرة: b.tone ?? null,
    };
    // موجز الشريك الحر يُضمّ إلى الموجز القياسي: مفاتيحه عربية أصلًا
    // (الفئة، الجمهور، العرض) فتقرؤها البرومبتات كما تقرأ حقولنا.
    const partnerBrief = (b.brief && typeof b.brief === "object")
      ? Object.entries(b.brief)
          .filter(([, v]) => v !== null && v !== "" && typeof v !== "object")
          .map(([k, v]) => `${k}: ${v}`)
      : [];
    const briefText = [
      ...Object.entries(brief)
        .filter(([, v]) => v !== null && v !== "")
        .map(([k, v]) => `${k}: ${v}`),
      ...partnerBrief,
    ].join("\n");

    // ١) الكاتب
    const w = await complete(key, writer.content, briefText);
    let variants = extractArray(w.text, "variants");
    if (!variants.length) return json({ ok: false, step: "writer", model: w.model, raw: w.text.slice(0, 400) }, 502);
    variants = variants.slice(0, 3);

    // ٢) الناقد
    const c = await complete(key, critic.content,
      `المنصة: ${platform}\nالموجز:\n${briefText}\n\nالاتجاهات:\n${JSON.stringify(variants, null, 1)}`);
    const scores = extractArray(c.text, "scores") as Array<
      Record<string, number | string>
    >;

    const tin  = w.tin + c.tin;
    const tout = w.tout + c.tout;
    const cost = isFree(w.model)
      ? 0
      : +(tin / 1e6 * IN_PER_M + tout / 1e6 * OUT_PER_M).toFixed(6);

    // ٣) سجل التوليد
    const gRes = await rest("generation_logs", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        merchant_id: b.merchant_id,
        prompt: briefText,
        output_text: JSON.stringify(variants),
        model: w.model, provider: PROVIDER === "openrouter" ? "openrouter" : "google",
        prompt_key: "ad_copy_system", prompt_version: writer.version,
        tokens_in: tin, tokens_out: tout, cost_usd: cost,
        latency_ms: Date.now() - t0, status: "ok",
        platform, brief,
      }),
    });
    const gRows = await gRes.json();
    if (!gRes.ok) return json({ ok: false, step: "log", error: gRows }, 500);
    const genId = gRows[0].id;

    // ٤) الاتجاهات مع درجات الناقد، مرتّبة بالأعلى
    const rows = variants.map((v, i) => {
      const s = scores.find((x) => Number(x.index) === i) ?? {};
      const angle = ANGLES.includes(String(v.angle)) ? String(v.angle) : ANGLES[i] ?? "منفعة";
      return {
        generation_id: genId, merchant_id: b.merchant_id, angle,
        headline: String(v.headline ?? "").slice(0, 200),
        body: v.body ? String(v.body).slice(0, 500) : null,
        cta: v.cta ? String(v.cta).slice(0, 100) : null,
        hashtags: Array.isArray(v.hashtags) ? v.hashtags.map(String).slice(0, 4) : null,
        score_total: s.total ?? null,
        scores: Object.keys(s).length ? s : null,
        fix_note: s.fix ?? null,
      };
    });
    rows.sort((a, b2) => Number(b2.score_total ?? 0) - Number(a.score_total ?? 0));
    rows.forEach((r, i) => ((r as Record<string, unknown>).rank = i + 1));

    const vRes = await rest("ad_variants", {
      method: "POST",
      headers: { Prefer: "return=representation" },
      body: JSON.stringify(rows),
    });
    const saved = await vRes.json();
    if (!vRes.ok) return json({ ok: false, step: "variants", error: saved }, 500);

    return json({
      ok: true, generation_id: genId, model: w.model, provider: PROVIDER,
      tokens: { in: tin, out: tout }, cost_usd: cost,
      cost_sar: +(cost * 3.75).toFixed(4),
      latency_ms: Date.now() - t0,
      variants: saved,
    });
  } catch (e) {
    const msg = String((e as Error).message ?? e);
    await rest("generation_logs", {
      method: "POST",
      body: JSON.stringify({
        merchant_id: b.merchant_id, prompt: b.product,
        model: MODEL, provider: PROVIDER === "openrouter" ? "openrouter" : "google",
        status: "error",
        error_code: msg.slice(0, 120), latency_ms: Date.now() - t0, platform,
      }),
    }).catch(() => {});
    return json({ ok: false, error: msg }, 502);
  }
});

function json(o: unknown, status = 200) {
  return new Response(JSON.stringify(o, null, 1), {
    status, headers: { "Content-Type": "application/json" },
  });
}
