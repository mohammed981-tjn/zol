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
// حصة النص عشرون نداءً في الدقيقة «لكل نموذج» — والتوليدة الواحدة تستهلك
// نحو عشرة. نموذجان يعني حصتين مستقلتين: حين يزدحم الأساسي يكمل الوكيل
// على الخفيف بدل أن يسقط دوره كله (شوهد حيًّا: مدير وناقد سقطا معًا).
const TEXT_FALLBACK = Deno.env.get("AI_TEXT_MODEL_FALLBACK") ?? "gemini-3.1-flash-lite";
const IMG_FAST = Deno.env.get("AI_IMAGE_MODEL_FAST") ?? "gemini-3.1-flash-image";
const IMG_BEST = Deno.env.get("AI_IMAGE_MODEL_BEST") ?? "gemini-3-pro-image";

/** نداء نصي بحصتين: الأساسي ثم الخفيف على 429/503 — لكلٍّ دقيقته. */
async function genText(key: string, payload: Record<string, unknown>) {
  let lastErr = "";
  for (const m of [TEXT_MODEL, TEXT_FALLBACK]) {
    const r = await fetch(`${G}/${m}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const j = await r.json();
    if (r.ok) return j;
    lastErr = `text_${r.status}:${(j?.error?.message ?? "").slice(0, 120)}`;
    if (r.status !== 429 && r.status !== 503) break;
  }
  throw new Error(lastErr);
}

type Body = {
  headline: string; subline?: string; cta?: string;
  bg_prompt?: string; primary?: string; accent?: string;
  name?: string; verify?: boolean;
  /** fast: مرشّحان سريعان. best: الثاني بالنموذج الأقوى + جولة تحسين. */
  quality?: "fast" | "best";
  /** صورة منتج التاجر الحقيقي: تُوضَع في المشهد توليديًا، وإن تعذّر
   *  ركّبها الخطاط حتميًا فوق الخلفية — المنتج يظهر في الحالتين. */
  product_url?: string;
  /** لوحة إخراج الفيديو نداء نصي كامل؛ من لا يستهلكها (ad-magic) يطفئها
   *  فيوفّر ثلاثة نداءات وثواني ثمينة من ميزانية عمر العامل. */
  storyboard?: boolean;
};

function b64(buf: Uint8Array): string {
  let s = "";
  for (let i = 0; i < buf.length; i += 8192) s += String.fromCharCode(...buf.subarray(i, i + 8192));
  return btoa(s);
}

async function textJson(key: string, system: string, user: string): Promise<Record<string, unknown>> {
  const j = await genText(key, {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: user }] }],
    generationConfig: { responseMimeType: "application/json", temperature: 0.9 },
  });
  const raw = j?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
  // النموذج قد يلفّ JSON بنص أو يذيّله — نقتطع أول قوس إلى آخره.
  const start = raw.indexOf("{"), end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("no_json");
  return JSON.parse(raw.slice(start, end + 1));
}

/** توليد صورة (نفس نمط ad-image المجرَّب) مع سقوط إلى pollinations المجاني. */
async function genImage(
  key: string, prompt: string, model: string,
  tag: string, trail: Record<string, unknown>, delayMs = 0,
): Promise<string> {
  // تفريق النداءين المتوازيين: مزوّد السقوط المجاني يحدّ بالطلب/الثانية،
  // ونداءان في اللحظة نفسها أسقطا كليهما بـ429 في أول تشغيل حيّ.
  if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
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
  } catch (e) {
    trail[`gen_${tag}_gemini`] = String((e as Error).message);
    const u = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}` +
      `?width=1080&height=1920&nologo=true&model=flux&safe=true`;
    for (let attempt = 0; attempt < 2; attempt++) {
      const r = await fetch(u, { headers: { "User-Agent": "AdCraft/1.0" } });
      if (r.status === 429 && attempt === 0) {
        await new Promise((res) => setTimeout(res, 1500));
        continue;
      }
      if (!r.ok) throw new Error(`pollinations_${r.status}`);
      const buf = new Uint8Array(await r.arrayBuffer());
      if (buf.length < 2000) throw new Error("pollinations_tiny");
      return b64(buf);
    }
    throw new Error("pollinations_429");
  }
}

/** الناقد البصري: يرى الصورتين معاً ويحكم — لا مقارنة أوصاف بل رؤية فعلية. */
async function judge(key: string, primary: string, a: string, bImg: string) {
  const rubric =
    `أنت ناقد إعلانات بصري صارم. أمامك صورتا خلفية لإعلان قصة عمودي، ` +
    `سيُكتب نص عربي أعلى كل صورة وزرّ أسفلها، ولون العلامة ${primary}.\n` +
    `قيّم كل صورة من ١٠ على: clean_zones (خلوّ الثلث الأعلى والأسفل من ` +
    `التفاصيل المزاحمة للنص)، harmony (انسجام الألوان مع لون العلامة)، ` +
    `appeal (جاذبية تجارية فورية — خلفية بيضاء فارغة أو باهتة بلا موضوع ` +
    `تهبط بها حادًّا)، defects (١٠ = بلا تشوّهات؛ عناصر ` +
    `ممسوخة أو نص عشوائي تهبط بها حادًّا).\n` +
    `مثال للشكل المطلوب حرفيًا (استبدل القيم): {"a":{"clean_zones":7,"harmony":6,` +
    `"appeal":8,"defects":9},"b":{"clean_zones":5,"harmony":7,"appeal":6,"defects":8},` +
    `"winner":"a","fix":"جملة تحسين واحدة للفائزة"}`;
  // مخطط إلزامي: أول تشغيل حيّ أعاد الناقدُ JSON مكسورًا فسقط حكمه —
  // المثال وحده لا يضمن، والمخطط يجبر البنية من المصدر.
  const scoreSchema = {
    type: "OBJECT",
    properties: {
      clean_zones: { type: "NUMBER" }, harmony: { type: "NUMBER" },
      appeal: { type: "NUMBER" }, defects: { type: "NUMBER" },
    },
    required: ["clean_zones", "harmony", "appeal", "defects"],
  };
  const j = await genText(key, {
    contents: [{ role: "user", parts: [
      { text: rubric },
      { text: "الصورة أ:" }, { inlineData: { mimeType: "image/png", data: a } },
      { text: "الصورة ب:" }, { inlineData: { mimeType: "image/png", data: bImg } },
    ] }],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          a: scoreSchema, b: scoreSchema,
          winner: { type: "STRING", enum: ["a", "b"] },
          fix: { type: "STRING" },
        },
        required: ["a", "b", "winner"],
      },
    },
  });
  const raw = j?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
  const start = raw.indexOf("{"), end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("judge_no_json");
  return JSON.parse(raw.slice(start, end + 1)) as {
    a: Record<string, number>; b: Record<string, number>;
    winner: "a" | "b"; fix?: string;
  };
}

const sum = (s: Record<string, number>) =>
  (s.clean_zones ?? 0) + (s.harmony ?? 0) + (s.appeal ?? 0) + (s.defects ?? 0);

/** وضع المنتج الحقيقي داخل المشهد توليديًا — شكله وملصقاته تُحفظ حرفيًا. */
async function placeProduct(
  key: string, prompt: string, pB64: string, pMime: string, model: string,
): Promise<string | null> {
  try {
    const r = await fetch(`${G}/${model}:generateContent`, {
      method: "POST",
      headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [
          { text: `Create a professional vertical advertising photograph: ${prompt}. ` +
                  `Place this exact product as the hero object in the middle third of the frame, ` +
                  `preserving its exact shape, colors, materials and label. ` +
                  `Keep the top and bottom thirds clean and calm for text overlays. ` +
                  `No text, no letters, no logos besides the product's own label.` },
          { inlineData: { mimeType: pMime, data: pB64 } },
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
async function compose(
  key: string, b: Body, bgUrl: string | null, productUrl: string | null = null,
) {
  const r = await fetch(`${SB_URL}/functions/v1/ad-compose`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-gemini-key": key },
    body: JSON.stringify({
      name: b.name, headline: b.headline, subline: b.subline, cta: b.cta,
      primary: b.primary, accent: b.accent, verify: b.verify,
      ...(bgUrl ? { bg_url: bgUrl } : { bg_prompt: b.bg_prompt }),
      ...(productUrl ? { product_url: productUrl } : {}),
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
        `كلاهما يترك الثلث الأعلى والأسفل هادئين للنص، بلا أي حروف داخل الصورة. ` +
        // خلفية بيضاء باهتة خرجت حيًّا وأغرقت حروف العنوان الفاتحة —
        // الهدوء المطلوب للنص يأتي من العمق والتعتيم لا من الفراغ الأبيض.
        `تجنّب تمامًا خلفية الاستوديو البيضاء أو الفاتحة الفارغة: مشهد غني ` +
        `بالعمق واللون والمزاج، بأجواء داكنة أو دافئة تحمل نصًّا فاتحًا فوقها.\n` +
        `أعد JSON فقط: {"concept_a":"...","concept_b":"...","negative":"..."}`);
      const neg = String(art.negative ?? "no text, no letters, no logos, no watermarks");
      promptA = `${art.concept_a}. ${neg}`;
      promptB = `${art.concept_b}. ${neg}`;
      trail.concepts = { a: art.concept_a, b: art.concept_b };
    } catch (e) {
      trail.art_director = `skipped: ${String((e as Error).message)}`;
    }

    // ١.٥) صورة المنتج الحقيقي إن وُجدت — تُجلب مرة واحدة للمصوّرَين معًا.
    let pB64: string | null = null;
    let pMime = "image/png";
    if (b.product_url) {
      try {
        const pr = await fetch(b.product_url, { headers: { "User-Agent": "AdCraft/1.0" } });
        if (pr.ok) {
          const buf = new Uint8Array(await pr.arrayBuffer());
          if (buf.length > 500) {
            pB64 = b64(buf);
            pMime = buf[0] === 0x89 ? "image/png" : "image/jpeg";
          }
        }
      } catch { /* بلا منتج */ }
      if (!pB64) trail.product = "fetch_failed";
    }

    // ٢) المصوّران بالتوازي — وفي وضع best ينفّذ الثاني بالنموذج الأقوى.
    // مع منتج حقيقي يُجرَّب وضعه توليديًا أولًا؛ إن تعذّر وُلدت خلفية
    // فقط وتكفّل الخطاط بتركيب القصاصة حتميًا — المنتج يظهر في الحالتين.
    const makeCandidate = async (
      prompt: string, model: string, tag: string, delayMs: number,
    ): Promise<{ img: string; placed: boolean }> => {
      if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
      if (pB64) {
        const placedImg = await placeProduct(key, prompt, pB64, pMime, model);
        if (placedImg) return { img: placedImg, placed: true };
        trail[`place_${tag}`] = "failed";
      }
      return { img: await genImage(key, prompt, model, tag, trail, 0), placed: false };
    };
    const tImg = Date.now();
    const settled = await Promise.allSettled([
      makeCandidate(promptA, IMG_FAST, "a", 0),
      makeCandidate(promptB, quality === "best" ? IMG_BEST : IMG_FAST, "b", 1200),
    ]);
    trail.candidates_ms = Date.now() - tImg;
    const alive = settled
      .filter((s): s is PromiseFulfilledResult<{ img: string; placed: boolean }> =>
        s.status === "fulfilled")
      .map((s) => s.value);
    if (!alive.length) {
      throw new Error(String((settled[0] as PromiseRejectedResult).reason));
    }

    // ٣) الناقد البصري يحكم — إن كان ثمة اثنان أصلًا. مرشّح واحد ناجٍ
    // يمضي بلا حكم: صورة بلا منافسة خير من لا صورة.
    let winner = alive[0], loser = alive[alive.length - 1], fix = "";
    if (alive.length === 2) {
      try {
        const v = await judge(key, primary, alive[0].img, alive[1].img);
        trail.scores = { a: v.a, b: v.b, winner: v.winner };
        if (v.winner === "b" || sum(v.b) > sum(v.a)) { winner = alive[1]; loser = alive[0]; }
        fix = String(v.fix ?? "");
        trail.winner_total = sum(v.winner === "b" ? v.b : v.a);
      } catch (e) {
        trail.judge = `skipped: ${String((e as Error).message)}`;
      }
    } else {
      trail.single_candidate = true;
    }
    if (pB64) trail.winner_placed = winner.placed;

    // ٤) الجرّاح — فقط في وضع best وحين رأى الناقد ما يُصلَح.
    if (quality === "best" && fix) {
      const better = await refine(key, winner.img, fix);
      if (better) { winner = { img: better, placed: winner.placed }; trail.refined = true; }
    }

    // ٥) الخطاط على الفائزة — ومعها المنتج إن لم يوضَع توليديًا،
    // ٦) وإن انكسرت الحروف أعاد الرسم على الوصيفة.
    const bgUrl = await upload(`${name}-bg.png`, Uint8Array.from(atob(winner.img), (c) => c.charCodeAt(0)));
    let composed = await compose(key, b, bgUrl,
      pB64 && !winner.placed ? b.product_url! : null);
    const broken = composed?.verify?.looks_broken === true ||
                   composed?.verify?.all_present === false;
    if (!composed?.ok || broken) {
      trail.retry_on_runner_up = true;
      const altUrl = await upload(`${name}-bg2.png`, Uint8Array.from(atob(loser.img), (c) => c.charCodeAt(0)));
      const second = await compose(key, b, altUrl,
        pB64 && !loser.placed ? b.product_url! : null);
      if (second?.ok && second?.verify?.looks_broken !== true) composed = second;
    }

    // ٧) لوحة الإخراج للفيديو — تُعاد للمستهلك ولا تُخزَّن: العمود غير
    // موجود بعد، والتصيير MP4 مرحلة قادمة (Veo غير متاح على هذا المفتاح).
    if (b.storyboard !== false) try {
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
      // قاع السلّم يحمل المنتج أيضًا: الخطاط يركّبه فوق خلفيته البسيطة.
      const plain = await compose(key, b, null, b.product_url ?? null);
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
