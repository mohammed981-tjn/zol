import 'config/app_role.dart';
import 'main.dart';

/// مدخل نكهة الإدارة.
///
///   flutter build apk --flavor admin -t lib/main_admin.dart
///
/// ولوحة الإدارة موجودة فعلًا (`AdminScreen`)، فهذه النكهة تعمل اليوم
/// لا غدًا — بخلاف نكهة المطبعة التي تنتظر صلاحيتها في الخادم.
void main() => bootstrap(pinned: AppRole.admin);
