import 'config/app_role.dart';
import 'main.dart';

/// مدخل نكهة المطبعة.
///
/// سطرٌ واحد بلا تهيئة خاصّة: كل الإقلاع في [bootstrap] المشترك، فلا
/// تفترق نكهةٌ عن أخرى عند أوّل تعديل في التهيئة.
///
/// البناء:
///   flutter build apk --flavor shop -t lib/main_shop.dart
void main() => bootstrap(pinned: AppRole.printShop);
