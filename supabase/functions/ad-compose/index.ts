import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Resvg, initWasm } from "npm:@resvg/resvg-wasm@2.6.2";

// v3: تطبيع المقارنة يوحّد ٪/% والأرقام الهندية/اللاتينية —
// المدقّق كان يرفض نصوصاً صحيحة لأن القارئ كتب % بدل ٪.
// v4: وترتيبها — اتجاه النص يقلب «٣٠٪» إلى «%30» عند القراءة،
// فتوحيد الحرف وحده لا يكفي: النسبة تُعاد دومًا بعد رقمها.

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const G = "https://generativelanguage.googleapis.com/v1beta/models";

let wasmReady: Promise<unknown> | null = null;
function ensureWasm() {
  if (!wasmReady) wasmReady = initWasm(fetch("https://unpkg.com/@resvg/resvg-wasm@2.6.2/index_bg.wasm"));
  return wasmReady;
}

const FONT_URLS = [
  "https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/Tajawal-Bold.ttf",
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/tajawal/Tajawal-Bold.ttf",
];
const FONT_REG_URLS = [
  "https://raw.githubusercontent.com/google/fonts/main/ofl/tajawal/Tajawal-Regular.ttf",
  "https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/tajawal/Tajawal-Regular.ttf",
];
let fontBold: Uint8Array | null = null;
let fontReg: Uint8Array | null = null;

async function fetchFirst(urls: string[]): Promise<Uint8Array> {
  for (const u of urls) {
    try {
      const r = await fetch(u);
      if (r.ok) { const b = new Uint8Array(await r.arrayBuffer()); if (b.length > 10_000) return b; }
    } catch { /* next */ }
  }
  throw new Error("font_fetch_failed");
}

function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
function b64(buf: Uint8Array): string {
  let s = "";
  for (let i = 0; i < buf.length; i += 8192) s += String.fromCharCode(...buf.subarray(i, i + 8192));
  return btoa(s);
}

const CHAR_W = 0.55;
function fitSize(text: string, maxWidth: number, idealSize: number, minSize: number): number {
  const need = Math.floor(maxWidth / (text.length * CHAR_W));
  return Math.max(minSize, Math.min(idealSize, need));
}
function wrap2(text: string): string[] {
  const words = text.split(/\s+/);
  if (words.length < 2) return [text];
  let best = 1, bestDiff = Infinity;
  for (let i = 1; i < words.length; i++) {
    const a = words.slice(0, i).join(" ").length, bl = words.slice(i).join(" ").length;
    const d = Math.abs(a - bl);
    if (d < bestDiff) { bestDiff = d; best = i; }
  }
  return [words.slice(0, best).join(" "), words.slice(best).join(" ")];
}

// تطبيع موحّد للمقارنة: تشكيل، همزات، تاء مربوطة، ٪←%، أرقام هندية←لاتينية
const AR_DIGITS = "٠١٢٣٤٥٦٧٨٩";
function norm(s: string): string {
  return s
    .replace(/[ً-ْٰ]/g, "")
    .replace(/[آأإ]/g, "ا")
    .replace(/ى/g, "ي").replace(/ة/g, "ه")
    .replace(/٪/g, "%")
    .replace(/[٠-٩]/g, (d) => String(AR_DIGITS.indexOf(d)))
    .replace(/[^\p{L}\p{N}%]/gu, "")
    .replace(/%(\p{N}+)/gu, "$1%");
}

type Body = {
  headline: string; subline?: string; cta?: string;
  bg_url?: string; bg_prompt?: string;
  primary?: string; accent?: string;
  name?: string; width?: number; height?: number; verify?: boolean;
  /** صورة منتج التاجر الحقيقي (قصاصة شفافة غالبًا) تُركَّب وسط الإعلان. */
  product_url?: string; product_b64?: string;
};

Deno.serve(async (req: Request) => {
  let b: Body;
  try { b = await req.json(); } catch { return json({ ok: false, error: "bad_json" }, 400); }
  if (!b?.headline) return json({ ok: false, error: "headline_required" }, 400);

  const W = b.width ?? 1080, H = b.height ?? 1920;
  const primary = b.primary ?? "#0B3D2E";
  const accent  = b.accent  ?? "#D4A017";
  const name = (b.name ?? "composed") + ".png";
  const t0 = Date.now();

  try {
    let bgBytes: Uint8Array; let bgMime = "image/png";
    if (b.bg_url) {
      const r = await fetch(b.bg_url);
      if (!r.ok) throw new Error(`bg_fetch_${r.status}`);
      bgMime = r.headers.get("content-type")?.split(";")[0] || "image/png";
      bgBytes = new Uint8Array(await r.arrayBuffer());
    } else if (b.bg_prompt) {
      const u = `https://image.pollinations.ai/prompt/${encodeURIComponent(b.bg_prompt + ", no text, no letters, no words")}` +
                `?width=${W}&height=${H}&nologo=true&model=flux&safe=true`;
      const r = await fetch(u, { headers: { "User-Agent": "AdCraft/1.0" } });
      if (!r.ok) throw new Error(`pollinations_${r.status}`);
      bgMime = r.headers.get("content-type")?.split(";")[0] || "image/jpeg";
      bgBytes = new Uint8Array(await r.arrayBuffer());
      if (bgBytes.length < 2000) throw new Error("pollinations_tiny");
    } else throw new Error("bg_url_or_bg_prompt_required");
    const bgMs = Date.now() - t0;

    // منتج التاجر الحقيقي — قصاصته تُركَّب فوق الخلفية في الثلث الأوسط،
    // فيظهر منتجه هو لا تخيّل النموذج عنه. غيابه أو تعذّره لا يمنع
    // الإعلان: المنتج إثراء والفشل هنا يكمل بلا تركيب.
    let productTag = "";
    if (b.product_url || b.product_b64) {
      try {
        let pBytes: Uint8Array | null = null;
        if (b.product_b64) {
          pBytes = Uint8Array.from(atob(b.product_b64), (c) => c.charCodeAt(0));
        } else if (b.product_url) {
          const pr = await fetch(b.product_url, { headers: { "User-Agent": "AdCraft/1.0" } });
          if (pr.ok) pBytes = new Uint8Array(await pr.arrayBuffer());
        }
        if (pBytes && pBytes.length > 500) {
          const pMime = pBytes[0] === 0x89 ? "image/png" : "image/jpeg";
          productTag = `<image href="data:${pMime};base64,${b64(pBytes)}"
    x="${Math.round(W * 0.10)}" y="${Math.round(H * 0.38)}"
    width="${Math.round(W * 0.80)}" height="${Math.round(H * 0.32)}"
    preserveAspectRatio="xMidYMid meet"/>`;
        }
      } catch { /* يكمل بلا تركيب */ }
    }

    await ensureWasm();
    if (!fontBold) fontBold = await fetchFirst(FONT_URLS);
    if (!fontReg) { try { fontReg = await fetchFirst(FONT_REG_URLS); } catch { fontReg = fontBold; } }

    const cx = W / 2;
    const safeW = W * 0.9;
    const parts: string[] = [];
    let y = H * 0.135;

    const one = fitSize(b.headline, safeW, Math.round(W * 0.102), 1);
    let hLines = [b.headline]; let hSize = one;
    if (one < Math.round(W * 0.062)) {
      hLines = wrap2(b.headline);
      hSize = Math.min(Math.round(W * 0.088),
        ...hLines.map((l) => fitSize(l, safeW, Math.round(W * 0.088), Math.round(W * 0.05))));
    }
    for (const line of hLines) {
      parts.push(`<text x="${cx}" y="${Math.round(y)}" text-anchor="middle" direction="rtl"
        font-family="Tajawal" font-weight="700" font-size="${hSize}" fill="${esc(accent)}">${esc(line)}</text>`);
      y += hSize * 1.22;
    }

    if (b.subline) {
      const sOne = fitSize(b.subline, safeW, Math.round(W * 0.049), 1);
      let sLines = [b.subline]; let sSize = sOne;
      if (sOne < Math.round(W * 0.034)) {
        sLines = wrap2(b.subline);
        sSize = Math.min(Math.round(W * 0.044),
          ...sLines.map((l) => fitSize(l, safeW, Math.round(W * 0.044), Math.round(W * 0.027))));
      }
      y += sSize * 0.5;
      for (const line of sLines) {
        parts.push(`<text x="${cx}" y="${Math.round(y)}" text-anchor="middle" direction="rtl"
          font-family="Tajawal" font-size="${sSize}" fill="#FFFFFF">${esc(line)}</text>`);
        y += sSize * 1.35;
      }
    }
    const topShade = Math.min(Math.round(y + H * 0.02), Math.round(H * 0.5));

    let ctaSvg = "";
    if (b.cta) {
      const cSize = Math.round(W * 0.045);
      const btnW = Math.min(W * 0.82, Math.max(W * 0.4, b.cta.length * cSize * CHAR_W + W * 0.12));
      const btnH = Math.round(H * 0.062);
      const btnY = Math.round(H * 0.855);
      ctaSvg = `
  <rect x="${Math.round(cx - btnW / 2)}" y="${btnY}" width="${Math.round(btnW)}" height="${btnH}"
        rx="${Math.round(btnH / 2)}" fill="${esc(primary)}" stroke="${esc(accent)}" stroke-width="3"/>
  <text x="${cx}" y="${btnY + Math.round(btnH * 0.68)}" text-anchor="middle" direction="rtl"
        font-family="Tajawal" font-weight="700" font-size="${cSize}" fill="${esc(accent)}">${esc(b.cta)}</text>`;
    }

    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}">
  <defs>
    <linearGradient id="top" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#000" stop-opacity="0.66"/>
      <stop offset="1" stop-color="#000" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="bot" x1="0" y1="1" x2="0" y2="0">
      <stop offset="0" stop-color="#000" stop-opacity="0.66"/>
      <stop offset="1" stop-color="#000" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <image href="data:${bgMime};base64,${b64(bgBytes)}" x="0" y="0" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice"/>
  <rect x="0" y="0" width="${W}" height="${topShade}" fill="url(#top)"/>
  <rect x="0" y="${Math.round(H * 0.72)}" width="${W}" height="${Math.round(H * 0.28)}" fill="url(#bot)"/>
  ${productTag}
  ${parts.join("\n")}
  ${ctaSvg}
</svg>`;

    const rsvg = new Resvg(svg, {
      fitTo: { mode: "width", value: W },
      font: { fontBuffers: [fontBold, fontReg!], defaultFontFamily: "Tajawal", loadSystemFonts: false },
    });
    const png = rsvg.render().asPng();
    const renderMs = Date.now() - t0 - bgMs;

    const up = await fetch(`${SB_URL}/storage/v1/object/ads/${name}`, {
      method: "POST",
      headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`,
                 "Content-Type": "image/png", "x-upsert": "true" },
      body: png,
    });
    const upTxt = await up.text();

    let verify: unknown = "skipped";
    const key = req.headers.get("x-gemini-key") ?? Deno.env.get("GEMINI_API_KEY") ?? "";
    if (b.verify !== false && key) {
      try {
        const expect = [b.headline, b.subline, b.cta].filter(Boolean) as string[];
        const vr = await fetch(`${G}/gemini-3.5-flash:generateContent`, {
          method: "POST",
          headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [
              { text: "اقرأ كل نص مرئي في الصورة حرفياً كما هو مكتوب، بلا تصحيح أو إكمال. أعد JSON فقط: {\"lines\":[],\"looks_broken\":false}" },
              { inlineData: { mimeType: "image/png", data: b64(png) } },
            ] }],
            generationConfig: { responseMimeType: "application/json" },
          }),
        });
        const vj = await vr.json();
        // عجز القارئ ليس دليل كسر: 429 عابر كان يُفسَّر «كل الحروف غائبة»
        // فيكذّب صورة سليمة ويطلق إعادة رسم بلا داع. الفشل هنا يعيد
        // { error } — والمستهلكون لا يعدّونه كسرًا، فقط «لم يُدقَّق».
        if (!vr.ok) throw new Error(`reader_${vr.status}`);
        const raw = vj?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).filter(Boolean).join("") ?? "";
        let read: { lines?: string[]; looks_broken?: boolean };
        try { read = JSON.parse(raw); } catch { throw new Error("reader_no_json"); }
        const seen = (read.lines ?? []).map(norm).join("");
        const found = expect.map((e) => ({ text: e, present: seen.includes(norm(e)) }));
        verify = { lines_read: read.lines ?? [], looks_broken: read.looks_broken ?? null,
                   expected: found, all_present: found.every((f) => f.present) };
      } catch (e) { verify = { error: String((e as Error).message) }; }
    }

    return json({
      ok: up.ok, bg_ms: bgMs, render_ms: renderMs, total_ms: Date.now() - t0,
      bytes: png.length, headline_size: hSize, headline_lines: hLines.length,
      upload: up.ok ? "stored" : upTxt.slice(0, 200),
      url: `${SB_URL}/storage/v1/object/public/ads/${name}`,
      ...(b.product_url || b.product_b64
        ? { product: productTag ? "overlaid" : "failed" }
        : {}),
      verify,
    });
  } catch (e) {
    return json({ ok: false, error: String((e as Error).message) }, 502);
  }
});

function json(o: unknown, status = 200) {
  return new Response(JSON.stringify(o, null, 1), {
    status, headers: { "Content-Type": "application/json" },
  });
}
