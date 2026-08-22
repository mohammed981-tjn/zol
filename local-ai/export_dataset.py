#!/usr/bin/env python3
"""استخراج مجموعة تدريب من سجل التوليد.

`generation_logs` يحفظ الموجز الذي أُرسل فعلًا، و`ad_variants` يحفظ الصيغ
الثلاث بدرجات الناقد ورتبها. هذا زوج تفضيلي جاهز لم يُصنع للتدريب لكنه
يصلح له تمامًا: المدخل موجز حقيقي من تاجر حقيقي، والحكم من الناقد نفسه
الذي يخدم المنتج اليوم.

التدريب على المخرجات المرتّبة يقطّر الكاتب والناقد معًا في نموذج واحد:
تمريرة محلية واحدة تحل محل تمريرتين سحابيتين.

    export SUPABASE_URL=https://<ref>.supabase.co
    export SUPABASE_SERVICE_ROLE_KEY=...
    python3 export_dataset.py --out data/

مفتاح service_role مطلوب لأن `generation_logs` محمي بـRLS. لا تضعه في git.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from collections import Counter
from pathlib import Path

import requests

PAGE = 500
ANGLES = ["منفعة", "فضول", "عرض"]


def _session(url: str, key: str) -> tuple[requests.Session, str]:
    if not url or not key:
        sys.exit(
            "مفقود: SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY.\n"
            "المفتاح من لوحة Supabase ← Project Settings ← API Keys ← service_role."
        )
    s = requests.Session()
    s.headers.update({"apikey": key, "Authorization": f"Bearer {key}"})
    return s, url.rstrip("/") + "/rest/v1"


def fetch_prompt(s: requests.Session, base: str, key: str) -> dict | None:
    """البرومبت الفعّال حاليًا — ليُدرَّب النموذج المحلي على نفس التعليمات."""
    r = s.get(
        f"{base}/prompts",
        params={"key": f"eq.{key}", "is_active": "eq.true", "select": "content,version"},
        timeout=30,
    )
    r.raise_for_status()
    rows = r.json()
    return rows[0] if rows else None


def fetch_generations(s: requests.Session, base: str, min_score: float) -> list[dict]:
    """كل توليدة ناجحة مع صيغها. PostgREST يدمج الجدولين في نداء واحد."""
    select = (
        "id,prompt,brief,platform,model,provider,created_at,"
        "ad_variants(angle,headline,body,cta,hashtags,score_total,rank,fix_note)"
    )
    out, offset = [], 0
    while True:
        r = s.get(
            f"{base}/generation_logs",
            params={"select": select, "status": "eq.ok", "order": "created_at.asc"},
            headers={"Range-Unit": "items", "Range": f"{offset}-{offset + PAGE - 1}"},
            timeout=60,
        )
        r.raise_for_status()
        batch = r.json()
        if not batch:
            break
        out.extend(batch)
        if len(batch) < PAGE:
            break
        offset += PAGE

    kept = []
    for g in out:
        vs = [v for v in (g.get("ad_variants") or []) if v.get("headline")]
        # بلا درجات لا تفضيل ولا ترتيب — السجل لا يصلح للتدريب.
        scored = [v for v in vs if v.get("score_total") is not None]
        if len(scored) < 2 or not (g.get("prompt") or "").strip():
            continue
        scored.sort(key=lambda v: (-float(v["score_total"]), v.get("rank") or 99))
        if float(scored[0]["score_total"]) < min_score:
            continue
        g["_ranked"] = scored
        kept.append(g)
    return kept


def variant_json(v: dict) -> dict:
    out = {
        "angle": v.get("angle") or ANGLES[0],
        "headline": v["headline"],
    }
    for k in ("body", "cta"):
        if v.get(k):
            out[k] = v[k]
    if v.get("hashtags"):
        out["hashtags"] = v["hashtags"]
    return out


def user_turn(g: dict) -> str:
    """يعيد بناء المدخل كما رآه النموذج السحابي وقت التوليد."""
    platform = g.get("platform") or "instagram"
    return f"المنصة: {platform}\nالموجز:\n{g['prompt'].strip()}"


def split_of(gen_id: str, val_ratio: float) -> str:
    """تقسيم ثابت بالتجزئة لا بالعشوائية — إعادة التشغيل تعطي نفس التقسيم."""
    h = int(hashlib.sha256(str(gen_id).encode()).hexdigest()[:8], 16)
    return "val" if (h % 1000) / 1000.0 < val_ratio else "train"


def build(gens: list[dict], mode: str, gap: float, val_ratio: float):
    sft = {"train": [], "val": []}
    dpo = {"train": [], "val": []}
    stats = Counter()

    for g in gens:
        ranked = g["_ranked"]
        split = split_of(g["id"], val_ratio)
        user = user_turn(g)

        target = (
            [variant_json(v) for v in ranked]
            if mode == "ranked"
            else [variant_json(ranked[0])]
        )
        sft[split].append(
            {
                "generation_id": g["id"],
                "messages": [
                    {"role": "user", "content": user},
                    {
                        "role": "assistant",
                        "content": json.dumps(
                            {"variants": target}, ensure_ascii=False, indent=1
                        ),
                    },
                ],
            }
        )
        stats[f"sft_{split}"] += 1

        best, worst = ranked[0], ranked[-1]
        delta = float(best["score_total"]) - float(worst["score_total"])
        if delta >= gap:
            dpo[split].append(
                {
                    "generation_id": g["id"],
                    "prompt": user,
                    "chosen": json.dumps(variant_json(best), ensure_ascii=False),
                    "rejected": json.dumps(variant_json(worst), ensure_ascii=False),
                    "score_delta": round(delta, 3),
                }
            )
            stats[f"dpo_{split}"] += 1
        else:
            stats["dpo_skipped_small_gap"] += 1

    return sft, dpo, stats


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")


def main() -> int:
    p = argparse.ArgumentParser(description="استخراج مجموعة تدريب من generation_logs")
    p.add_argument("--out", default="data", help="مجلد الإخراج")
    p.add_argument(
        "--mode",
        choices=["ranked", "best"],
        default="ranked",
        help="ranked: الصيغ الثلاث بترتيب الناقد (يطابق سلوك التطبيق). best: الأفضل وحدها.",
    )
    p.add_argument("--min-score", type=float, default=0.0, help="أدنى درجة للصيغة الأفضل")
    p.add_argument("--gap", type=float, default=1.0, help="أدنى فارق درجات لزوج DPO")
    p.add_argument("--val-ratio", type=float, default=0.15)
    args = p.parse_args()

    s, base = _session(
        os.environ.get("SUPABASE_URL", ""),
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
    )

    out = Path(args.out)
    gens = fetch_generations(s, base, args.min_score)
    if not gens:
        print("لا توليدات صالحة. تحقق من وجود صفوف status=ok بدرجات في ad_variants.")
        return 1

    sft, dpo, stats = build(gens, args.mode, args.gap, args.val_ratio)

    for split in ("train", "val"):
        write_jsonl(out / f"sft_{split}.jsonl", sft[split])
        write_jsonl(out / f"dpo_{split}.jsonl", dpo[split])

    meta = {"mode": args.mode, "counts": dict(stats), "prompts": {}}
    for key in ("ad_copy_system", "ad_critic_system"):
        pr = fetch_prompt(s, base, key)
        if pr:
            meta["prompts"][key] = pr
    (out / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"توليدات صالحة: {len(gens)}")
    for k in sorted(stats):
        print(f"  {k}: {stats[k]}")
    print(f"\nكُتبت في {out.resolve()}")

    total = stats["sft_train"]
    if total < 200:
        print(
            f"\n⚠️  {total} مثال تدريب فقط. LoRA يعطي نتيجة معقولة من ~٥٠٠،"
            "\n   ودون ذلك يحفظ الأمثلة بدل أن يتعلّم الأسلوب. شغّل التوليد أكثر أولًا."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
