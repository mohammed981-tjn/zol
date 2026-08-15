#!/usr/bin/env python3
"""قياس النموذج المحلي أمام المخرجات السحابية على نفس المدخلات.

مرحلتان منفصلتان عمدًا: التوليد يحتاج GPU، والتحكيم يحتاج شبكة، وقلّما
تجتمعان في آلة واحدة.

    # على آلة بـGPU
    python3 evaluate.py generate --data data/ --model google/gemma-3-4b-it \
        --adapter out/sft --out preds.jsonl

    # حيثما توفّر مفتاح المزوّد
    export OPENROUTER_API_KEY=...
    python3 evaluate.py judge --data data/ --preds preds.jsonl

المحكّم هو `ad_critic_system` نفسه الذي يخدم الإنتاج — لا مقياس مخترع
لهذه التجربة. والمقارنة عمياء: يُعرض عليه الاتجاهان بترتيب مقلوب لنصف
العينات، وإلا كافأ الأول لكونه أولًا لا لكونه أفضل.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import statistics
import sys
from pathlib import Path

import requests


def read_jsonl(p: Path) -> list[dict]:
    return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines() if l.strip()]


def cmd_generate(args) -> int:
    import torch
    from peft import PeftModel
    from transformers import AutoModelForCausalLM, AutoTokenizer

    meta_path = args.data / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    system = (meta.get("prompts", {}).get("ad_copy_system") or {}).get("content")

    tok = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForCausalLM.from_pretrained(
        args.model, dtype=torch.bfloat16, device_map="auto"
    )
    if args.adapter:
        model = PeftModel.from_pretrained(model, args.adapter)
    model.eval()

    rows = read_jsonl(args.data / "sft_val.jsonl")
    out = []
    for i, r in enumerate(rows, 1):
        user = r["messages"][0]["content"]
        msgs = ([{"role": "system", "content": system}] if system else []) + [
            {"role": "user", "content": user}
        ]
        ids = tok.apply_chat_template(
            msgs, add_generation_prompt=True, return_tensors="pt"
        ).to(model.device)
        with torch.no_grad():
            gen = model.generate(
                ids, max_new_tokens=512, do_sample=True, temperature=0.8, top_p=0.95
            )
        text = tok.decode(gen[0][ids.shape[-1]:], skip_special_tokens=True)
        out.append({"generation_id": r["generation_id"], "prompt": user, "local": text})
        if i % 10 == 0:
            print(f"  {i}/{len(rows)}", flush=True)

    args.out.write_text(
        "\n".join(json.dumps(o, ensure_ascii=False) for o in out), encoding="utf-8"
    )
    print(f"كُتبت {len(out)} توليدة في {args.out}")
    return 0


def call_judge(system: str, user: str) -> str:
    """يستدعي المحكّم عبر OpenRouter أو جيميناي حسب المفتاح المتاح."""
    if key := os.environ.get("OPENROUTER_API_KEY"):
        r = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
            json={
                "model": os.environ.get("JUDGE_MODEL", "google/gemini-2.5-flash"),
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                "temperature": 0,
            },
            timeout=120,
        )
        r.raise_for_status()
        return r.json()["choices"][0]["message"]["content"]

    if key := os.environ.get("GEMINI_API_KEY"):
        model = os.environ.get("JUDGE_MODEL", "gemini-2.5-flash")
        r = requests.post(
            f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            headers={"x-goog-api-key": key, "Content-Type": "application/json"},
            json={
                "systemInstruction": {"parts": [{"text": system}]},
                "contents": [{"role": "user", "parts": [{"text": user}]}],
                "generationConfig": {"temperature": 0},
            },
            timeout=120,
        )
        r.raise_for_status()
        return r.json()["candidates"][0]["content"]["parts"][0]["text"]

    sys.exit("لا مفتاح محكّم: اضبط OPENROUTER_API_KEY أو GEMINI_API_KEY.")


def cmd_judge(args) -> int:
    meta = json.loads((args.data / "meta.json").read_text(encoding="utf-8"))
    critic = (meta.get("prompts", {}).get("ad_critic_system") or {}).get("content")
    if not critic:
        sys.exit("لا برومبت ناقد في meta.json — أعد تشغيل export_dataset.py.")

    baseline = {r["generation_id"]: r["messages"][1]["content"] for r in read_jsonl(args.data / "sft_val.jsonl")}
    preds = read_jsonl(args.preds)

    local_s, cloud_s, wins, ties = [], [], 0, 0
    for i, p in enumerate(preds, 1):
        gid = p["generation_id"]
        if gid not in baseline:
            continue
        # ترتيب مقلوب لنصف العيّنات: تجزئة ثابتة لا عشوائية.
        flip = int(hashlib.sha256(str(gid).encode()).hexdigest()[:2], 16) % 2 == 1
        a, b = (p["local"], baseline[gid]) if not flip else (baseline[gid], p["local"])

        user = (
            f"{p['prompt']}\n\nالاتجاهات (أ):\n{a}\n\nالاتجاهات (ب):\n{b}\n\n"
            'قيّم كل مجموعة على حدة بنفس معاييرك، وأعد JSON فقط: '
            '{"a":{"total":<رقم>},"b":{"total":<رقم>}}'
        )
        try:
            raw = call_judge(critic, user)
            data = json.loads(re.search(r"\{.*\}", raw, re.S).group(0))
            sa, sb = float(data["a"]["total"]), float(data["b"]["total"])
        except Exception as e:  # noqa: BLE001
            print(f"  تعذّر تحكيم {gid}: {e}")
            continue

        loc, cld = (sa, sb) if not flip else (sb, sa)
        local_s.append(loc)
        cloud_s.append(cld)
        if loc > cld:
            wins += 1
        elif loc == cld:
            ties += 1
        if i % 10 == 0:
            print(f"  {i}/{len(preds)}", flush=True)

    n = len(local_s)
    if not n:
        print("لم يُحكَّم أي مثال.")
        return 1

    print(f"\nعيّنات محكَّمة: {n}")
    print(f"متوسط المحلي:  {statistics.mean(local_s):.2f}")
    print(f"متوسط السحابي: {statistics.mean(cloud_s):.2f}")
    print(f"فوز المحلي: {wins}/{n} ({wins / n:.0%}) | تعادل: {ties}")
    delta = statistics.mean(local_s) - statistics.mean(cloud_s)
    print(f"الفارق: {delta:+.2f}")
    print(
        "\nالحكم: "
        + (
            "المحلي يكفي — انقل التوليد إلى الجهاز واترك السحابي احتياطًا."
            if delta > -0.5
            else "الفجوة واسعة — زد البيانات أو جرّب أساسًا أكبر قبل النقل."
        )
    )
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="قياس النموذج المحلي أمام السحابي")
    sub = p.add_subparsers(dest="cmd", required=True)

    g = sub.add_parser("generate", help="توليد بالنموذج المحلي (يحتاج GPU)")
    g.add_argument("--data", type=Path, default=Path("data"))
    g.add_argument("--model", required=True)
    g.add_argument("--adapter", default=None)
    g.add_argument("--out", type=Path, default=Path("preds.jsonl"))
    g.set_defaults(func=cmd_generate)

    j = sub.add_parser("judge", help="تحكيم المخرجات بالناقد السحابي")
    j.add_argument("--data", type=Path, default=Path("data"))
    j.add_argument("--preds", type=Path, default=Path("preds.jsonl"))
    j.set_defaults(func=cmd_judge)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
