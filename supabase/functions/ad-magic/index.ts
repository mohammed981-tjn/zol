import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// شاشة السحر — السلسلة الكاملة في نداء واحد:
// موجز التاجر ← الكاتب (٣ زوايا + مشهد لكل زاوية) ← الناقد ←
// ٣ صور بالتوازي (مشهد + حروف عربية مرسومة) ← مدقّق ← السجل.

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const G = "https://generativelanguage.googleapis.com/v1beta/models";
const MODEL = Deno.env.get("AI_TEXT_MODEL") ?? "gemini-3.5-flash";
const FALLBACK_MODEL = Deno.env.get("AI_TEXT_MODEL_FALLBACK") ?? "gemini-3.1-flash-lite";
const IN_PER_M  = Number(Deno.env.get("AI_PRICE_IN")  ?? "0.30");
const OUT_PER_M = Number(Deno.env.get("AI_PRICE_OUT") ?? "2.50");

const rest = (path: string, init: RequestInit = {}) =>
  fetch(`${SB_URL}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`,
               "Content-Type": "application/json", ...(init.headers ?? {}) },
  });

async function getPrompt(key: string) {
  const r = await rest(`prompts?key=eq.${key}&is_active=eq.true&select=content,version`);
  const rows = await r.json();
  if (!Array.isArray(rows) || !rows.length) throw new Error(`prompt_missing:${key}`);
  return rows[0] as { content: string; version: number };
}

// إعادة محاولة على الأخطاء العابرة (503/429)، ثم نموذج احتياطي
async function gemini(key: string, system: string, user: string) {
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
      return { text, model: m, tin: u.promptTokenCount ?? 0,
               tout: (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0) };
    }
    lastErr = `gemini_${r.status}:${j?.error?.message ?? ""}`;
    if (r.status !== 503 && r.status !== 429) break;   // خطأ دائم — لا تكرر
  }
  throw new Error(lastErr);
}

const ANGLES = ["منفعة", "فضول", "عرض"];

Deno.serve(async (req: Request) => {
  const key = req.headers.get("x-gemini-key") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
  if (!key) return json({ ok: false, error: "no_api_key" }, 400);

  let b: {
    merchant_id: string; product: string; platform?: string;
    audience?: string; offer?: string; season?: string; dialect?: string;
    brand_name?: string; tone?: string; primary?: string; accent?: string;
    images?: boolean;
  };
  try { b = await req.json(); } catch { return json({ ok: false, error: "bad_json" }, 400); }
  if (!b?.merchant_id || !b?.product) return json({ ok: false, error: "merchant_id_and_product_required" }, 400);

  const platform = b.platform ?? "سناب شات";
  const primary = b.primary ?? "#0B3D2E";
  const accent  = b.accent  ?? "#D4A017";
  const t0 = Date.now();

  try {
    const writer = await getPrompt("ad_copy_system");
    const critic = await getPrompt("ad_critic_system");

    const brief: Record<string, unknown> = {
      العلامة: b.brand_name ?? null, المنتج: b.product, المنصة: platform,
      الجمهور: b.audience ?? null, العرض: b.offer ?? null, الموسم: b.season ?? null,
      اللهجة: b.dialect ?? "فصحى مبسّطة", النبرة: b.tone ?? null,
    };
    const briefText = Object.entries(brief)
      .filter(([, v]) => v !== null && v !== "").map(([k, v]) => `${k}: ${v}`).join("\n");

    // ١) الكاتب
    const w = await gemini(key, writer.content, briefText);
    let variants: Array<Record<string, unknown>> = [];
    try { variants = JSON.parse(w.text).variants ?? []; } catch { /* below */ }
    if (!variants.length) return json({ ok: false, step: "writer", raw: w.text.slice(0, 300) }, 502);
    variants = variants.slice(0, 3);

    // ٢) الناقد
    const c = await gemini(key, critic.content,
      `المنصة: ${platform}\nالموجز:\n${briefText}\n\nالاتجاهات:\n${JSON.stringify(variants.map(v => ({angle: v.angle, headline: v.headline, body: v.body, cta: v.cta})), null, 1)}`);
    let scores: Array<Record<string, number | string>> = [];
    try { scores = JSON.parse(c.text).scores ?? []; } catch { /* tolerate */ }

    const tin = w.tin + c.tin, tout = w.tout + c.tout;
    const cost = +(tin / 1e6 * IN_PER_M + tout / 1e6 * OUT_PER_M).toFixed(6);

    // ٣) سجل التوليد
    const gRes = await rest("generation_logs", {
      method: "POST", headers: { Prefer: "return=representation" },
      body: JSON.stringify({
        merchant_id: b.merchant_id, prompt: briefText,
        output_text: JSON.stringify(variants),
        model: w.model, provider: "google",
        prompt_key: "ad_copy_system", prompt_version: writer.version,
        tokens_in: tin, tokens_out: tout, cost_usd: cost,
        latency_ms: Date.now() - t0, status: "ok", platform, brief,
      }),
    });
    const gRows = await gRes.json();
    if (!gRes.ok) return json({ ok: false, step: "log", error: gRows }, 500);
    const genId = gRows[0].id as string;

    // ٤) ثلاث صور بالتوازي — مشهد كل زاوية من وصف الكاتب نفسه
    const makeImages = b.images !== false;
    let images: Array<{ url: string | null; verified: boolean | null }> =
      variants.map(() => ({ url: null, verified: null }));
    if (makeImages) {
      images = await Promise.all(variants.map(async (v, i) => {
        try {
          const scene = String(v.scene ?? "") ||
            `Professional vertical product photograph related to: ${b.product}, warm lighting, clean space at top and bottom, no text, no letters, no logos`;
          const r = await fetch(`${SB_URL}/functions/v1/ad-compose`, {
            method: "POST",
            headers: { "Content-Type": "application/json", "x-gemini-key": key },
            body: JSON.stringify({
              name: `magic-${genId.slice(0, 8)}-${i}`,
              headline: v.headline, subline: v.body, cta: v.cta,
              primary, accent, bg_prompt: scene, verify: true,
            }),
          });
          const j = await r.json();
          if (!j.ok) return { url: null, verified: null };
          return { url: j.url as string, verified: j.verify?.all_present ?? null };
        } catch { return { url: null, verified: null }; }
      }));
    }

    // ٥) الحفظ مرتّباً بحكم الناقد
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
        image_url: images[i].url,
        image_verified: images[i].verified,
      };
    });
    rows.sort((a, b2) => Number(b2.score_total ?? 0) - Number(a.score_total ?? 0));
    rows.forEach((r, i) => ((r as Record<string, unknown>).rank = i + 1));

    const vRes = await rest("ad_variants", {
      method: "POST", headers: { Prefer: "return=representation" },
      body: JSON.stringify(rows),
    });
    const saved = await vRes.json();
    if (!vRes.ok) return json({ ok: false, step: "variants", error: saved }, 500);

    // ٦) أفضل صورة تصير صورة التوليدة
    const best = rows.find((r) => r.image_url)?.image_url ?? null;
    await rest(`generation_logs?id=eq.${genId}`, {
      method: "PATCH",
      body: JSON.stringify({ output_image_url: best, media_kind: best ? "image" : null,
                             latency_ms: Date.now() - t0 }),
    });

    return json({
      ok: true, generation_id: genId, model: w.model,
      tokens: { in: tin, out: tout }, cost_usd: cost,
      cost_sar: +(cost * 3.75).toFixed(4), latency_ms: Date.now() - t0,
      variants: saved,
    });
  } catch (e) {
    const msg = String((e as Error).message ?? e);
    await rest("generation_logs", {
      method: "POST",
      body: JSON.stringify({ merchant_id: b.merchant_id, prompt: b.product,
        model: MODEL, provider: "google", status: "error",
        error_code: msg.slice(0, 120), latency_ms: Date.now() - t0, platform }),
    }).catch(() => {});
    return json({ ok: false, error: msg }, 502);
  }
});

function json(o: unknown, status = 200) {
  return new Response(JSON.stringify(o, null, 1), {
    status, headers: { "Content-Type": "application/json" },
  });
}
