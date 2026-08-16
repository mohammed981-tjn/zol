import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const G = "https://generativelanguage.googleapis.com/v1beta/models";

type Body = {
  prompt: string;
  expect?: string[];
  provider?: "gemini" | "pollinations" | "cloudflare";
  model?: string;
  aspect?: string;
  width?: number;
  height?: number;
  name?: string;
  verify?: boolean;
};

function norm(s: string): string {
  return s
    .replace(/[ً-ْٰ]/g, "")
    .replace(/[آأإ]/g, "ا")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[‌-‏]/g, "")
    .replace(/[^\p{L}\p{N}%٪]/gu, "")
    .trim();
}

async function genGemini(key: string, prompt: string, model: string, aspect: string) {
  const r = await fetch(`${G}/${model}:generateContent`, {
    method: "POST",
    headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { responseModalities: ["IMAGE"], imageConfig: { aspectRatio: aspect } },
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`gemini_${r.status}: ${j?.error?.message ?? "unknown"}`);
  const inline = (j?.candidates?.[0]?.content?.parts ?? [])
    .find((p: { inlineData?: { data: string } }) => p.inlineData)?.inlineData;
  if (!inline) throw new Error(`gemini_no_image: ${j?.candidates?.[0]?.finishReason ?? ""}`);
  return { b64: inline.data as string, usage: j?.usageMetadata ?? null };
}

async function genPollinations(prompt: string, w: number, h: number, model: string) {
  const u = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}` +
    `?width=${w}&height=${h}&nologo=true&model=${encodeURIComponent(model)}&safe=true`;
  const r = await fetch(u, { headers: { "User-Agent": "AdCraft/1.0" } });
  if (!r.ok) throw new Error(`pollinations_${r.status}: ${(await r.text()).slice(0, 160)}`);
  const buf = new Uint8Array(await r.arrayBuffer());
  if (buf.length < 2000) throw new Error(`pollinations_tiny_${buf.length}`);
  let s = "";
  for (let i = 0; i < buf.length; i += 8192) s += String.fromCharCode(...buf.subarray(i, i + 8192));
  return { b64: btoa(s), usage: null };
}

async function genCloudflare(prompt: string, model: string) {
  const acct = Deno.env.get("CF_ACCOUNT_ID") ?? "";
  const tok  = Deno.env.get("CF_API_TOKEN") ?? "";
  if (!acct || !tok) throw new Error("cloudflare_not_configured");
  const r = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${acct}/ai/run/${model}`,
    { method: "POST", headers: { Authorization: `Bearer ${tok}`, "Content-Type": "application/json" },
      body: JSON.stringify({ prompt }) });
  if (!r.ok) throw new Error(`cloudflare_${r.status}: ${(await r.text()).slice(0, 160)}`);
  const ct = r.headers.get("content-type") ?? "";
  if (ct.includes("application/json")) {
    const j = await r.json();
    const b64 = j?.result?.image;
    if (!b64) throw new Error("cloudflare_no_image");
    return { b64: b64 as string, usage: null };
  }
  const buf = new Uint8Array(await r.arrayBuffer());
  let s = "";
  for (let i = 0; i < buf.length; i += 8192) s += String.fromCharCode(...buf.subarray(i, i + 8192));
  return { b64: btoa(s), usage: null };
}

Deno.serve(async (req: Request) => {
  let b: Body;
  try { b = await req.json(); }
  catch { return json({ ok: false, error: "bad_json" }, 400); }
  if (!b?.prompt) return json({ ok: false, error: "prompt_required" }, 400);

  const provider = b.provider ?? "gemini";
  const aspect = b.aspect ?? "9:16";
  const w = b.width ?? 1080;
  const h = b.height ?? 1920;
  const name = (b.name ?? "ad") + ".png";
  const key = req.headers.get("x-gemini-key") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
  const t0 = Date.now();

  let out: { b64: string; usage: unknown };
  try {
    if (provider === "pollinations") {
      out = await genPollinations(b.prompt, w, h, b.model ?? "flux");
    } else if (provider === "cloudflare") {
      out = await genCloudflare(b.prompt, b.model ?? "@cf/black-forest-labs/flux-1-schnell");
    } else {
      if (!key) return json({ ok: false, error: "no_api_key" }, 400);
      out = await genGemini(key, b.prompt, b.model ?? "gemini-3-pro-image", aspect);
    }
  } catch (e) {
    return json({ ok: false, step: "generate", provider, error: String((e as Error).message) }, 502);
  }
  const genMs = Date.now() - t0;

  const bin = Uint8Array.from(atob(out.b64), (c) => c.charCodeAt(0));
  const up = await fetch(`${SB_URL}/storage/v1/object/ads/${name}`, {
    method: "POST",
    headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`,
               "Content-Type": "image/png", "x-upsert": "true" },
    body: bin,
  });
  const upTxt = await up.text();

  // مدقّق الحروف العربية — يقرأ النص من الصورة ويقارنه بالمطلوب
  let verify: unknown = "skipped";
  if (b.verify !== false && key) {
    try {
      const vr = await fetch(`${G}/gemini-3.5-flash:generateContent`, {
        method: "POST",
        headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [
            { text: "اقرأ كل نص مرئي في الصورة حرفياً كما هو مكتوب، دون تصحيح أو تخمين أو إكمال. إن كان هناك حرف مشوّه أو مقطوع فاكتبه كما يبدو. أعد JSON فقط: {\"lines\":[],\"looks_broken\":false,\"notes\":\"\"}" },
            { inlineData: { mimeType: "image/png", data: out.b64 } },
          ] }],
          generationConfig: { responseMimeType: "application/json" },
        }),
      });
      const vj = await vr.json();
      const raw = vj?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
      let read: { lines?: string[]; looks_broken?: boolean; notes?: string } = {};
      try { read = JSON.parse(raw); } catch { /* ignore */ }
      const seen = (read.lines ?? []).map(norm).join("|");
      const expect = b.expect ?? [];
      const found = expect.map((e) => ({ text: e, present: seen.includes(norm(e)) }));
      verify = {
        lines_read: read.lines ?? [],
        looks_broken: read.looks_broken ?? null,
        notes: read.notes ?? "",
        expected: found,
        all_present: found.length > 0 && found.every((f) => f.present),
      };
    } catch (e) { verify = { error: String((e as Error).message) }; }
  }

  return json({
    ok: up.ok, provider, model: b.model ?? null,
    gen_ms: genMs, total_ms: Date.now() - t0,
    bytes: bin.length, usage: out.usage,
    upload: up.ok ? "stored" : upTxt.slice(0, 200),
    url: `${SB_URL}/storage/v1/object/public/ads/${name}`,
    verify,
  });
});

function json(o: unknown, status = 200) {
  return new Response(JSON.stringify(o, null, 1), {
    status, headers: { "Content-Type": "application/json" },
  });
}
