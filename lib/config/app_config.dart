/// إعداد التطبيق.
///
/// عنوان المنسّق يُمرَّر وقت البناء فلا يُدفن في الشيفرة:
///   flutter run --dart-define=ORCHESTRATOR_URL=http://10.0.2.2:8080
///
/// لا يوجد ولن يوجد أي مفتاح مزوّد هنا: التطبيق لا يعرف اسم النموذج
/// المستخدم ولا يملك صلاحية استدعائه مباشرة.
class AppConfig {
  AppConfig._();

  static const String orchestratorUrl = String.fromEnvironment(
    'ORCHESTRATOR_URL',
    // 8080 لا 8899: هو المنفذ الذي يستمع عليه server/src/server.ts وهو
    // الموثّق في server/README.md. القيمة السابقة كانت تشير إلى منفذ لا
    // يسمع فيه أحد، فيفشل التوليد بخطأ اتصال بلا سبب ظاهر.
    defaultValue: 'http://localhost:8080',
  );

  /// أي عقل خلفي يُستعمل: `supabase` (الافتراضي) أو `orchestrator`.
  ///
  /// عقل Supabase هو المنشور والعامل فعلاً، وهو وحده من يمنح كل صيغة درجة
  /// من الوكيل الناقد ويسجّل التكلفة في generation_logs الذي تقرأه لوحة
  /// الإدارة. منسّق Node يبقى خياراً للتشغيل المحلي بلا سحابة.
  static const String backend = String.fromEnvironment(
    'AI_BACKEND',
    defaultValue: 'supabase',
  );

  static bool get useSupabase => backend != 'orchestrator';

  /// عنوان مشروع Supabase، بلا شرطة مائلة في آخره.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// المفتاح العلني (publishable/anon) — مصمَّم للمتصفح والتطبيق، وليس سرّاً.
  /// المفاتيح السرّية تبقى في بيئة الدوال وحدها.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// معرّف التاجر. مؤقت حتى تُبنى المصادقة: دالة ad-copy تشترطه لتنسب
  /// التوليد لصاحبه في generation_logs.
  static const String merchantId = String.fromEnvironment('MERCHANT_ID');

  /// النبرات — يجب أن تطابق TONES في الخادم.
  static const List<String> tones = ['حماسي', 'كوميدي', 'رسمي', 'عاطفي'];

  /// المنصات — يجب أن تطابق PLATFORMS في الخادم.
  static const List<String> platforms = ['إنستغرام', 'تيك توك', 'فيسبوك', 'سناب شات'];
}
