#!/usr/bin/env bash
#
# تقليم إصدارات GitHub: كل إصدار عمرُه يتجاوز الحدّ يُحذف هو ووسمه.
#
# ثلاث قواعد بترتيب أسبقية، وكلٌّ منها له سبب:
#   KEEP_MIN      أحدث إصدار لا يُحذف أبدًا مهما شاخ. بدون هذه القاعدة
#                 تمرّ سبعة أيام بلا بناء فتُمحى كل النسخ ويبقى التاجر
#                 بلا شيء يثبّته — والقاعدة التي تترك المستخدم بلا تطبيق
#                 خطأٌ لا سياسة.
#   KEEP_MAX      ما تجاوز هذا العدد يُحذف فورًا مهما كان جديدًا. القيمة
#                 ١ تعني «الأحدث وحده يبقى» — وهي المطلوبة هنا: صفحة
#                 الإصدارات تعرض نسخة واحدة صالحة لا ستّين نسخة يحتار
#                 بينها من يريد التثبيت.
#   MAX_AGE_DAYS  وما بينهما (حين يُرفع KEEP_MAX) يُحذف عند تجاوز العمر.
#
# الاستعمال (داخل GitHub Actions، وGH_TOKEN مضبوط):
#   MAX_AGE_DAYS=7 KEEP_MIN=1 KEEP_MAX=1 tool/prune_releases.sh
#   DRY_RUN=true tool/prune_releases.sh      # عرض ما سيُحذف بلا حذف
set -euo pipefail

MAX_AGE_DAYS="${MAX_AGE_DAYS:-7}"
KEEP_MIN="${KEEP_MIN:-1}"
KEEP_MAX="${KEEP_MAX:-1}"
DRY_RUN="${DRY_RUN:-false}"
REPO="${REPO:-${GITHUB_REPOSITORY:-}}"

if [ -z "$REPO" ]; then
  echo "REPO أو GITHUB_REPOSITORY مطلوب" >&2
  exit 1
fi

now=$(date -u +%s)
cutoff=$(( now - MAX_AGE_DAYS * 86400 ))

# الأحدث أولًا: الترتيب هو أساس قاعدتَي KEEP_MIN وKEEP_MAX.
mapfile -t rows < <(
  gh release list --repo "$REPO" --limit 300 \
    --json tagName,publishedAt \
    --jq 'sort_by(.publishedAt) | reverse | .[] | [.tagName, .publishedAt] | @tsv'
)

rank=0
deleted=0
kept=0

for row in "${rows[@]}"; do
  [ -n "$row" ] || continue
  rank=$(( rank + 1 ))
  tag="${row%%$'\t'*}"
  published="${row#*$'\t'}"
  pub_ts=$(date -u -d "$published" +%s)
  age_days=$(( (now - pub_ts) / 86400 ))

  reason=""
  if [ "$rank" -le "$KEEP_MIN" ]; then
    reason="keep:أحدث نسخة محميّة"
  elif [ "$rank" -gt "$KEEP_MAX" ]; then
    reason="delete:تجاوز عدد المحفوظات ($KEEP_MAX)"
  elif [ "$pub_ts" -lt "$cutoff" ]; then
    reason="delete:عمره ${age_days} يومًا > ${MAX_AGE_DAYS}"
  else
    reason="keep:عمره ${age_days} يومًا"
  fi

  if [ "${reason%%:*}" = "delete" ]; then
    if [ "$DRY_RUN" = "true" ]; then
      echo "سيُحذف  $tag — ${reason#*:}"
    else
      # حذف الوسم مع الإصدار: وسمٌ يتيم بلا إصدار يوهم بوجود نسخة.
      gh release delete "$tag" --repo "$REPO" --cleanup-tag --yes
      echo "حُذف    $tag — ${reason#*:}"
    fi
    deleted=$(( deleted + 1 ))
  else
    echo "أُبقي   $tag — ${reason#*:}"
    kept=$(( kept + 1 ))
  fi
done

echo "—"
echo "المجموع: $rank · محذوف: $deleted · مُبقى: $kept" \
     "(الحدّ ${MAX_AGE_DAYS} يومًا، محفوظ من $KEEP_MIN إلى $KEEP_MAX)"
