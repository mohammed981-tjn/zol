/// إعداد الاتصال بمشروع Supabase (الخادم الخلفي لـ zol).
///
/// الرابط ومفتاح publishable ليسا سرّيين — مصمَّمان أصلًا للتضمين في
/// تطبيقات العميل (يُطبَّق كل التحكم الأمني عبر Row Level Security على
/// الجداول، لا عبر إخفاء هذا المفتاح). مفتاح service_role السرّي لا
/// يظهر هنا ولا في أي كود عميل أبدًا.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = 'https://fygettwuhlmkjotqzwhs.supabase.co';
  static const String publishableKey =
      'sb_publishable_6HaY3BxEUeKmEYhuH2Ovlg_9ApLuAnM';
}
