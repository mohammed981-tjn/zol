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

  /// النبرات — يجب أن تطابق TONES في الخادم.
  static const List<String> tones = ['حماسي', 'كوميدي', 'رسمي', 'عاطفي'];

  /// المنصات — يجب أن تطابق PLATFORMS في الخادم.
  static const List<String> platforms = ['إنستغرام', 'تيك توك', 'فيسبوك', 'سناب شات'];
}
