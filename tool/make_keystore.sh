#!/usr/bin/env bash
# يولّد مفتاح توقيع الإصدار ويطبع الأسرار الأربعة المطلوبة في GitHub.
#
# شغّله مرة واحدة فقط. المفتاح الناتج هو هوية التطبيق الدائمة: كل نسخة
# مستقبلية توقَّع به، وفقدانه يعني أن لا نسخة جديدة تستطيع تحديث المثبَّتة
# على أجهزة المستخدمين — لا سبيل لاستعادته ولا لإصداره من جديد.
#
#     bash tool/make_keystore.sh
#
# ثم انسخ القيم إلى Settings ← Secrets and variables ← Actions.

set -euo pipefail

OUT="${1:-zol-release.jks}"
ALIAS="zol"
VALIDITY_DAYS=10950  # ٣٠ سنة — أقصر من ذلك يعني انتهاء صلاحية التوقيع يومًا ما

if [ -e "$OUT" ]; then
  echo "خطأ: $OUT موجود مسبقًا. لا تولّد فوقه — قد يكون هو مفتاح تطبيقك." >&2
  exit 1
fi

command -v keytool >/dev/null || {
  echo "خطأ: keytool غير موجود. ثبّت JDK (مثلًا: apt install default-jdk)." >&2
  exit 1
}

# كلمتا مرور عشوائيتان — لا داعي لحفظهما يدويًا، ستُخزَّنان في الأسرار.
STORE_PASS="$(head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 28)"
KEY_PASS="$STORE_PASS"

keytool -genkeypair -v \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 \
  -validity "$VALIDITY_DAYS" \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=Zol, OU=Zol, O=Zol, L=Riyadh, S=Riyadh, C=SA" >/dev/null

echo
echo "تم توليد $OUT"
echo "بصمته (هذه هوية تطبيقك من الآن):"
keytool -list -v -keystore "$OUT" -storepass "$STORE_PASS" \
  | grep -i "SHA256:" | head -1
echo
echo "════════ أضف هذه الأربعة في GitHub ════════"
echo "Settings ← Secrets and variables ← Actions ← New repository secret"
echo
echo "ANDROID_KEY_ALIAS"
echo "$ALIAS"
echo
echo "ANDROID_KEYSTORE_PASSWORD"
echo "$STORE_PASS"
echo
echo "ANDROID_KEY_PASSWORD"
echo "$KEY_PASS"
echo
echo "ANDROID_KEYSTORE_BASE64"
base64 -w0 "$OUT" 2>/dev/null || base64 "$OUT" | tr -d '\n'
echo
echo
echo "══════════════════════════════════════════"
echo "احتفظ بـ$OUT في مكان آمن خارج المستودع."
echo ".gitignore يمنع رفعه، لكن النسخة الاحتياطية مسؤوليتك."
