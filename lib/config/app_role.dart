/// دور من يستعمل التطبيق — التاجر أم المطبعة أم الإدارة.
///
/// **لماذا هذا الملفّ قبل النكهات**: «نكهة بناء» و«جذر واعٍ بالدور» ليسا
/// خيارين متقابلين بل مرحلتان. الجذر شيفرةٌ يجب أن توجد أوّلًا — لا وجود
/// لشاشة مطبعة قبل أن يعرف التطبيق أنه ينظر إلى مطبعة. والنكهة تغليفٌ
/// يأتي بعده: نفس الشيفرة تُقسَّم إلى ثلاث حزم بإدراجات منفصلة.
///
/// وبعد هذا الملفّ تصير النكهة **مفتاحًا يُقلَب** لا مشروعًا يُبدأ:
///
///   ١) ملفّ مدخل لكل نكهة، سطران فيه:
///        `// lib/main_shop.dart`
///        `void main() => bootstrap(pinned: AppRole.printShop);`
///
///   ٢) و‏`productFlavors` في `android/app/build.gradle.kts` يعطي كلّ
///      نكهة `applicationId` واسمًا وأيقونة.
///
///   ٣) والبناء: `flutter build apk --flavor shop -t lib/main_shop.dart`.
///
/// ولا شيء في بقيّة الشيفرة يتغيّر: الجذر يقرأ [AppRole] ولا يعرف من
/// أين جاء.
library;

/// الأدوار الثلاثة.
enum AppRole {
  /// التاجر — واجهة توليد الإعلانات والطباعة. الافتراضي.
  merchant,

  /// المطبعة — طوابير الطباعة وحالاتها.
  printShop,

  /// إدارة المنصّة — الطلبات والمطابع والمناديب وسجل التوليد.
  admin,
}

/// الدور المثبَّت وقت البناء، إن ثُبِّت.
///
/// `--dart-define=ZOL_ROLE=shop` هو بالضبط ما ستمرّره نكهةُ البناء
/// لاحقًا، فيصير الانتقال إلى النكهات تغييرًا في **أمر البناء** لا في
/// الشيفرة. وحتى قبل النكهات يعمل: حزمة واحدة تُبنى مرّتين بقيمتين.
const _pinnedRole = String.fromEnvironment('ZOL_ROLE');

/// يحسم الدور: المثبَّت وقت البناء أوّلًا، ثم ما تقوله هويّة الحساب.
///
/// [pinned] يغلب كل شيء — به تعمل ملفّات المداخل. وبعده `ZOL_ROLE`.
/// وإلّا فالدور من الحساب: [isShopOwner] لمن يملك مطبعة معتمدة،
/// و[isAdmin] لمن يملك المنصّة.
///
/// والافتراض **تاجر** لا مجهول: أكثر من يفتح التطبيق تاجر، وزائرٌ بلا
/// حساب يجب أن يرى ما يفهمه لا شاشة اختيار دور لا تعنيه.
AppRole resolveRole({
  AppRole? pinned,
  bool isShopOwner = false,
  bool isAdmin = false,
}) {
  if (pinned != null) return pinned;

  switch (_pinnedRole) {
    case 'shop':
    case 'printShop':
      return AppRole.printShop;
    case 'admin':
      return AppRole.admin;
    case 'merchant':
      return AppRole.merchant;
  }

  // ترتيب الأسبقية حين يجمع شخصٌ صفتين: الإدارة أوسع، فمن يملك المنصّة
  // ويملك مطبعةً يرى لوحة المنصّة — ومن أراد لوحة مطبعته دخل بحسابها.
  if (isAdmin) return AppRole.admin;
  if (isShopOwner) return AppRole.printShop;
  return AppRole.merchant;
}
