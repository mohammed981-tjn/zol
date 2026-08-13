/// إعداد التطبيق.
///
/// عنوان المنسّق يُمرَّر وقت البناء فلا يُدفن في الشيفرة:
///   flutter run --dart-define=ORCHESTRATOR_URL=http://10.0.2.2:8899
///
/// لا يوجد ولن يوجد أي مفتاح مزوّد هنا: التطبيق لا يعرف اسم النموذج
/// المستخدم ولا يملك صلاحية استدعائه مباشرة.
class AppConfig {
  AppConfig._();

  static const String orchestratorUrl = String.fromEnvironment(
    'ORCHESTRATOR_URL',
    defaultValue: 'http://localhost:8899',
  );

  /// النبرات — يجب أن تطابق TONES في الخادم.
  static const List<String> tones = ['حماسي', 'كوميدي', 'رسمي', 'عاطفي'];

  /// المنصات — يجب أن تطابق PLATFORMS في الخادم.
  static const List<String> platforms = ['إنستغرام', 'تيك توك', 'فيسبوك', 'سناب شات'];
}
