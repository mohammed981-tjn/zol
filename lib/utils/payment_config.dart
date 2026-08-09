// إعدادات بوابة الدفع في مكان واحد — منقول من zadgo2.
//
// ⚠️ قاعدة أمنية لا تُخالَف: المفتاح المنشور (publishable) وحده يُوضع في
// التطبيق. المفتاح السري (secret) يُستخدم على الخادم فقط — وضعه هنا يعني
// تسليمه لكل من يفكّ حزمة التطبيق.
//
// المفتاح يُمرَّر عند البناء بلا وضعه في المستودع:
//   flutter build apk --dart-define=MOYASAR_PUBLISHABLE_KEY=pk_live_xxx
class AppPaymentConfig {
  AppPaymentConfig._();

  /// مفتاح ميسر المنشور. يبقى فارغًا حتى يُمرَّر عند البناء.
  static const String moyasarPublishableKey = String.fromEnvironment(
    'MOYASAR_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// هل الدفع بالبطاقة مهيّأ فعلًا؟ تُفحص قبل عرض شاشة البوابة —
  /// وبدونها يُعرض وضع المحاكاة التجريبي بوضوح.
  static bool get isConfigured => moyasarPublishableKey.trim().isNotEmpty;

  /// هل المفتاح للاختبار (sandbox)؟ يُعرض تنبيه حتى لا يُظن أن مبلغًا
  /// حقيقيًا سُحب.
  static bool get isTestKey => moyasarPublishableKey.startsWith('pk_test');

  /// سعر الاشتراك الاحترافي الشهري (يعادل ‎29$‎ من نموذج الربح).
  static const double proMonthlyPriceSar = 109;
}
