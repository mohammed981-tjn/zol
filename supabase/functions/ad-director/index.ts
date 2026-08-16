import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// المخرج الفني — عقل بصري متعدد الوكلاء فوق سلسلة الصور.
//
// المولّد الواحد يعطيك أول خاطرة. هذا يدير غرفة إخراج كاملة:
//   ١) مدير فني  : يحوّل المشهد إلى مفهومين بصريين متعارضين عمداً
//   ٢) مصوّران   : ينفّذان المفهومين بالتوازي
//   ٣) ناقد بصري : «يرى» الصورتين ويحكم بمعايير — نظافة مناطق النص،
//                  الانسجام مع لون العلامة، الجاذبية، العيوب
//   ٤) جرّاح     : يحسّن الفائزة (إضاءة/تنظيف) دون كسر تكوينها
//   ٥) الخطاط    : ad-compose ترسم الحروف العربية وتدقّقها
//   ٦) القاضي    : إن انكسرت الحروف أعاد الرسم على الوصيفة
//
// كل درجة في السلّم تفشل بأمان إلى ما دونها، وآخر الدرج ad-compose
// القديمة نفسها — فالعقل الجديد لا يستطيع أن يكون أسوأ من سابقه.

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const G = "https://generativelanguage.googleapis.com/v1beta/models";
const TEXT_MODEL = Deno.env.get("AI_TEXT_MODEL") ?? "gemini-3.5-flash";
const IMG_FAST = Deno.env.get("AI_IMAGE_MODEL_FAST") ?? "gemini-3.1-flash-image";
const IMG_BEST = Deno.env.get("AI_IMAGE_MODEL_BEST") ?? "gemini-3-pro-image";

type Body = {
  headline: string; subline?: string; cta?: string;
  bg_prompt?: string; primary?: string; accent?: string;
  name?: string; verify?: boolean;
  /** fast: مرشّحان سريعان. best: الثاني بالنموذج الأقوى + جولة تحسين. */
  quality?: "fast" | "best";
};

function b64(buf: Uint8Array): string {
  let s = "";
  for (let i = 0; i < buf.length; i += 8192) s += String.fromCharCode(...buf.subarray(i, i + 8192));
  return btoa(s);
}

async function textJson(key: string, system: string, user: string): Promise<Record<string, unknown>> {
  const r = await fetch(`${G}/${TEXT_MODEL}:generateContent`, {
    method: "POST",
    headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: { responseMimeType: "application/json", temperature: 1.1 },
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`text_${r.status}:${j?.error?.message ?? ""}`);
  const raw = j?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
  return JSON.parse(raw);
}

/** توليد صورة (نفس نمط ad-image المجرَّب) مع سقوط إلى pollinations المجاني. */
async function genImage(key: string, prompt: string, model: string): Promise<string> {
  try {
    const r = await fetch(`${G}/${model}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { responseModalities: ["IMAGE"], imageConfig: { aspectRatio: "9:16" } },
      }),
    });
    const j = await r.json();
    if (!r.ok) throw new Error(`gemini_${r.status}`);
    const inline = (j?.candidates?.[0]?.content?.parts ?? [])
      .find((p: { inlineData?: { data: string } }) => p.inlineData)?.inlineData;
    if (!inline?.data) throw new Error("no_image");
    return inline.data as string;
  } catch (_) {
    const u = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}` +
      `?width=1080&height=1920&nologo=true&model=flux&safe=true`;
    const r = await fetch(u, { headers: { "User-Agent": "AdCraft/1.0" } });
    if (!r.ok) throw new Error(`pollinations_${r.status}`);
    const buf = new Uint8Array(await r.arrayBuffer());
    if (buf.length < 2000) throw new Error("pollinations_tiny");
    return b64(buf);
  }
}

/** الناقد البصري: يرى الصورتين معاً ويحكم — لا مقارنة أوصاف بل رؤية فعلية. */
async function judge(key: string, primary: string, a: string, bImg: string) {
  const rubric =
    `أنت ناقد إعلانات بصري صارم. أمامك صورتا خلفية لإعلان قصة عمودي، ` +
    `سيُكتب نص عربي أعلى كل صورة وزرّ أسفلها، ولون العلامة ${primary}.\n` +
    `قيّم كل صورة من ١٠ على: clean_zones (خلوّ الثلث الأعلى والأسفل من ` +
    `التفاصيل المزاحمة للنص)، harmony (انسجام الألوان مع لون العلامة)، ` +
    `appeal (جاذبية تجارية فورية)، defects (١٠ = بلا تشوّهات؛ عناصر ` +
    `ممسوخة أو نص عشوائي تهبط بها حادًّا).\n` +
    `أعد JSON فقط: {"a":{"clean_zones":0,"harmony":0,"appeal":0,"defects":0},` +
    `"b":{...},"winner":"a"|"b","fix":"جملة تحسين واحدة للفائزة"}`;
  const r = await fetch(`${G}/${TEXT_MODEL}:generateContent`, {
    method: "POST",
    headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [
        { text: rubric },
        { text: "الصورة أ:" }, { inlineData: { mimeType: "image/png", data: a } },
        { text: "الصورة ب:" }, { inlineData: { mimeType: "image/png", data: bImg } },
      ] }],
      generationConfig: { responseMimeType: "application/json" },
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`judge_${r.status}`);
  const raw = j?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
  return JSON.parse(raw) as {
    a: Record<string, number>; b: Record<string, number>;
    winner: "a" | "b"; fix?: string;
  };
}

const sum = (s: Record<string, number>) =>
  (s.clean_zones ?? 0) + (s.harmony ?? 0) + (s.appeal ?? 0) + (s.defects ?? 0);

/** جرّاح التحسين: تعديل صورة←صورة يحفظ التكوين ويعالج ما رصده الناقد. */
async function refine(key: string, img: string, fix: string): Promise<string | null> {
  try {
    const r = await fetch(`${G}/${IMG_BEST}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [
          { text: `حسّن هذه الصورة مع الحفاظ التام على تكوينها وموضوعها: ${fix}. ` +
                  `أبقِ الثلث الأعلى والأسفل هادئين لنصٍّ سيُضاف. لا تضف أي حروف أو شعارات.` },
          { inlineData: { mimeType: "image/png", data: img } },
        ] }],
        generationConfig: { responseModalities: ["IMAGE"], imageConfig: { aspectRatio: "9:16" } },
      }),
    });
    const j = await r.json();
    if (!r.ok) return null;
    const inline = (j?.candidates?.[0]?.content?.parts ?? [])
      .find((p: { inlineData?: { data: string } }) => p.inlineData)?.inlineData;
    return (inline?.data as string) ?? null;
  } catch (_) {
    return null;
  }
}

async function upload(name: string, png: Uint8Array): Promise<string> {
  const up = await fetch(`${SB_URL}/storage/v1/object/ads/${name}`, {
    method: "POST",
    headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`,
               "Content-Type": "image/png", "x-upsert": "true" },
    body: png,
  });
  if (!up.ok) throw new Error(`upload_${up.status}`);
  return `${SB_URL}/storage/v1/object/public/ads/${name}`;
}

/** الخطاط: نفس ad-compose القائمة — لا نعيد اختراع رسم الحروف. */
async function compose(key: string, b: Body, bgUrl: string | null) {
  const r = await fetch(`${SB_URL}/functions/v1/ad-compose`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-gemini-key": key },
    body: JSON.stringify({
      name: b.name, headline: b.headline, subline: b.subline, cta: b.cta,
      primary: b.primary, accent: b.accent, verify: b.verify,
      ...(bgUrl ? { bg_url: bgUrl } : { bg_prompt: b.bg_prompt }),
    }),
  });
  return await r.json();
}

Deno.serve(async (req: Request) => {
  const key = req.headers.get("x-gemini-key") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
  let b: Body;
  try { b = await req.json(); } catch { return json({ ok: false, error: "bad_json" }, 400); }
  if (!b?.headline) return json({ ok: false, error: "headline_required" }, 400);
  if (!b.bg_prompt) return json({ ok: false, error: "bg_prompt_required" }, 400);

  const quality = b.quality ?? "fast";
  const primary = b.primary ?? "#0B3D2E";
  const name = b.name ?? "directed";
  const t0 = Date.now();
  const trail: Record<string, unknown> = {};

  try {
    if (!key) throw new Error("no_api_key");

    // ١) المدير الفني: مفهومان متعارضان عمداً — التنويع قبل الحكم.
    let promptA = b.bg_prompt, promptB = b.bg_prompt + ", alternative composition, different lighting";
    try {
      const art = await textJson(key,
        "أنت مدير فني لإعلانات المنتجات. تكتب برومبتات تصوير بالإنجليزية.",
        `المشهد المطلوب: ${b.bg_prompt}\nالعنوان الذي سيُكتب فوقه: ${b.headline}\n` +
        `لون العلامة: ${primary}\n` +
        `اكتب مفهومين بصريين متعمّدَي الاختلاف (زاوية كاميرا، إضاءة، مزاج) لنفس المشهد، ` +
        `كلاهما يترك الثلث الأعلى والأسفل هادئين للنص، بلا أي حروف داخل الصورة.\n` +
        `أعد JSON فقط: {"concept_a":"...","concept_b":"...","negative":"..."}`);
      const neg = String(art.negative ?? "no text, no letters, no logos, no watermarks");
      promptA = `${art.concept_a}. ${neg}`;
      promptB = `${art.concept_b}. ${neg}`;
      trail.concepts = { a: art.concept_a, b: art.concept_b };
    } catch (e) {
      trail.art_director = `skipped: ${String((e as Error).message)}`;
    }

    // ٢) المصوّران بالتوازي — وفي وضع best ينفّذ الثاني بالنموذج الأقوى.
    const tImg = Date.now();
    const [candA, candB] = await Promise.all([
      genImage(key, promptA, IMG_FAST),
      genImage(key, promptB, quality === "best" ? IMG_BEST : IMG_FAST),
    ]);
    trail.candidates_ms = Date.now() - tImg;

    // ٣) الناقد البصري يحكم. تعادلٌ أو فشلٌ ⇒ الأولى، فلا يقف الإنتاج على حكم.
    let winner = candA, loser = candB, fix = "";
    try {
      const v = await judge(key, primary, candA, candB);
      trail.scores = { a: v.a, b: v.b, winner: v.winner };
      if (v.winner === "b" || sum(v.b) > sum(v.a)) { winner = candB; loser = candA; }
      fix = String(v.fix ?? "");
      trail.winner_total = sum(v.winner === "b" ? v.b : v.a);
    } catch (e) {
      trail.judge = `skipped: ${String((e as Error).message)}`;
    }

    // ٤) الجرّاح — فقط في وضع best وحين رأى الناقد ما يُصلَح.
    if (quality === "best" && fix) {
      const better = await refine(key, winner, fix);
      if (better) { winner = better; trail.refined = true; }
    }

    // ٥) الخطاط على الفائزة، ٦) وإن انكسرت الحروف أعاد الرسم على الوصيفة.
    const bgUrl = await upload(`${name}-bg.png`, Uint8Array.from(atob(winner), (c) => c.charCodeAt(0)));
    let composed = await compose(key, b, bgUrl);
    const broken = composed?.verify?.looks_broken === true ||
                   composed?.verify?.all_present === false;
    if (!composed?.ok || broken) {
      trail.retry_on_runner_up = true;
      const altUrl = await upload(`${name}-bg2.png`, Uint8Array.from(atob(loser), (c) => c.charCodeAt(0)));
      const second = await compose(key, b, altUrl);
      if (second?.ok && second?.verify?.looks_broken !== true) composed = second;
    }

    // ٧) لوحة الإخراج للفيديو — تُعاد للمستهلك ولا تُخزَّن: العمود غير
    // موجود بعد، والتصيير MP4 مرحلة قادمة (Veo غير متاح على هذا المفتاح).
    try {
      const sb = await textJson(key,
        "أنت مخرج إعلانات قصيرة. أعد JSON فقط.",
        `إعلان قصة عمودي. العنوان: ${b.headline}. الزر: ${b.cta ?? ""}. المشهد: ${b.bg_prompt}.\n` +
        `اكتب لوحة إخراج من ٣ لقطات لريلز ٩ ثوانٍ: ` +
        `{"shots":[{"ms":3000,"camera":"...","action":"...","overlay":"النص الظاهر"}],"music":"وصف موجز"}`);
      trail.storyboard = sb;
    } catch (_) { /* الفيديو إثراء لا شرط */ }

    return json({
      ...composed,
      director: { quality, ...trail, total_ms: Date.now() - t0 },
    });
  } catch (e) {
    // آخر الدرج: السلوك القديم حرفياً — العقل الجديد لا يكون أسوأ من سابقه.
    trail.fallback = String((e as Error).message);
    try {
      const plain = await compose(key, b, null);
      return json({ ...plain, director: { degraded: true, ...trail } });
    } catch (e2) {
      return json({ ok: false, error: String((e2 as Error).message), director: trail }, 502);
    }
  }
});

function json(o: unknown, status = 200) {
  return new Response(JSON.stringify(o, null, 1), {
    status, headers: { "Content-Type": "application/json" },
  });
}
