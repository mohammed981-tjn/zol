#!/usr/bin/env python3
"""تدريب مُهايئ LoRA على مخرجات سجل التوليد.

يحتاج GPU — لا يعمل في بيئة الجلسة. شغّله على Colab أو أي آلة بكرت رسومي:

    pip install -U transformers peft trl datasets accelerate bitsandbytes
    python3 train_lora.py --data data/ --model google/gemma-3-4b-it --out out/

مرحلتان:
  SFT  — يتعلّم الصيغة والأسلوب من الصيغ التي ارتضاها الناقد.
  DPO  — اختيارية، تشدّ المخرجات نحو الأعلى درجةً بعيدًا عن الأدنى.

DPO بلا SFT قبلها لا معنى له: النموذج الأساس لا يعرف بعدُ صيغة الإخراج
المطلوبة، فالتفضيل يقارن ركامًا بركام.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

# النماذج التي تستحق التجربة لحالة عربية إعلانية على الجهاز.
PRESETS = {
    "gemma": "google/gemma-3-4b-it",
    "gemma-small": "google/gemma-3-1b-it",
    "falcon-ar": "tiiuae/Falcon-H1-3B-Instruct",  # عربي أصالةً
    "qwen": "Qwen/Qwen3-4B-Instruct",
}


def load_split(data: Path, name: str):
    from datasets import Dataset

    path = data / name
    if not path.exists():
        return None
    rows = [json.loads(l) for l in path.read_text(encoding="utf-8").splitlines() if l.strip()]
    return Dataset.from_list(rows) if rows else None


def with_system(ds, system: str | None):
    """يحقن برومبت النظام الفعّال ليطابق التدريبُ ما يراه النموذج في الإنتاج."""
    if not system or ds is None:
        return ds
    return ds.map(lambda r: {"messages": [{"role": "system", "content": system}, *r["messages"]]})


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--data", type=Path, default=Path("data"))
    p.add_argument("--out", type=Path, default=Path("out"))
    p.add_argument("--model", default="gemma", help=f"اسم مختصر {list(PRESETS)} أو معرّف HF كامل")
    p.add_argument("--epochs", type=float, default=3.0)
    p.add_argument("--lr", type=float, default=2e-4)
    p.add_argument("--rank", type=int, default=16)
    p.add_argument("--batch", type=int, default=2)
    p.add_argument("--accum", type=int, default=8)
    p.add_argument("--max-len", type=int, default=1024)
    p.add_argument("--dpo", action="store_true", help="مرحلة DPO بعد SFT")
    p.add_argument("--no-4bit", action="store_true", help="تعطيل التحميل بـ4-bit")
    args = p.parse_args()

    import torch
    from peft import LoraConfig
    from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
    from trl import SFTConfig, SFTTrainer

    if not torch.cuda.is_available():
        raise SystemExit("لا GPU. شغّل هذا على Colab أو آلة بكرت رسومي.")

    model_id = PRESETS.get(args.model, args.model)
    meta_path = args.data / "meta.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
    system = (meta.get("prompts", {}).get("ad_copy_system") or {}).get("content")

    train = with_system(load_split(args.data, "sft_train.jsonl"), system)
    val = with_system(load_split(args.data, "sft_val.jsonl"), system)
    if train is None:
        raise SystemExit(f"لا ملف sft_train.jsonl في {args.data}. شغّل export_dataset.py أولًا.")
    print(f"النموذج: {model_id}\nتدريب: {len(train)} | تحقق: {len(val) if val else 0}")

    quant = (
        None
        if args.no_4bit
        else BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_use_double_quant=True,
        )
    )

    tok = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(
        model_id, quantization_config=quant, dtype=torch.bfloat16, device_map="auto"
    )

    lora = LoraConfig(
        r=args.rank,
        lora_alpha=args.rank * 2,
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
        target_modules=[
            "q_proj", "k_proj", "v_proj", "o_proj",
            "gate_proj", "up_proj", "down_proj",
        ],
    )

    sft_dir = args.out / "sft"
    trainer = SFTTrainer(
        model=model,
        train_dataset=train,
        eval_dataset=val,
        peft_config=lora,
        processing_class=tok,
        args=SFTConfig(
            output_dir=str(sft_dir),
            num_train_epochs=args.epochs,
            per_device_train_batch_size=args.batch,
            gradient_accumulation_steps=args.accum,
            learning_rate=args.lr,
            lr_scheduler_type="cosine",
            warmup_ratio=0.03,
            logging_steps=10,
            eval_strategy="epoch" if val else "no",
            save_strategy="epoch",
            bf16=True,
            max_length=args.max_len,
            gradient_checkpointing=True,
            report_to=[],
        ),
    )
    trainer.train()
    trainer.save_model(str(sft_dir))
    print(f"مُهايئ SFT في {sft_dir}")

    if args.dpo:
        from trl import DPOConfig, DPOTrainer

        dtrain = load_split(args.data, "dpo_train.jsonl")
        if dtrain is None or len(dtrain) < 50:
            print(f"تخطّي DPO: {len(dtrain) if dtrain else 0} زوج فقط — أقل من أن يُحسّن شيئًا.")
        else:
            dpo_dir = args.out / "dpo"
            DPOTrainer(
                model=trainer.model,
                train_dataset=dtrain,
                eval_dataset=load_split(args.data, "dpo_val.jsonl"),
                processing_class=tok,
                args=DPOConfig(
                    output_dir=str(dpo_dir),
                    num_train_epochs=1,
                    per_device_train_batch_size=1,
                    gradient_accumulation_steps=args.accum,
                    learning_rate=5e-6,
                    beta=0.1,
                    logging_steps=10,
                    bf16=True,
                    report_to=[],
                ),
            ).train()
            print(f"مُهايئ DPO في {dpo_dir}")

    print(
        "\nالخطوة التالية — التحويل للجهاز:\n"
        "  LiteRT/‏MediaPipe: ai-edge-torch generative converter ثم .task\n"
        "  llama.cpp:        convert_hf_to_gguf.py ثم llama-quantize Q4_K_M\n"
        "قِس أولًا بـ evaluate.py قبل أن تتكبّد التحويل."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
