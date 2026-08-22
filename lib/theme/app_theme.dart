import 'package:flutter/material.dart';

/// اسم الخط العربي المضمَّن. يُصرَّح صريحاً في كل TextStyle مبني يدوياً،
/// لأن TextStyle المُنشأ داخل ثيم مكوّن لا يرث fontFamily من ThemeData —
/// وإغفاله يُسقط النص على الخط الافتراضي فيظهر بطباعة مختلفة أو لا يظهر
/// أصلاً على الويب حين يتعذّر تحميل الخط الافتراضي.
///
/// القيمة `Tajawal` لا `Cairo`: الفرع اعتمد Tajawal خطَّ الواجهة وأبقى
/// Cairo وAlmarai خيارَي «خط العلامة التجارية» في Brand Kit، وخمسة مواضع
/// في الواجهة تثبّت Tajawal صراحةً — فلو بقي الثابت على Cairo لانقسمت
/// الواجهة بين خطين. تبديلها سطر واحد إن أُريد العكس.
const String kFontFamily = 'Tajawal';

/// ألوان العلامة.
///
/// الكحلي هوية، والمرجاني فعل، والذهبي زينة — وهذا التقسيم مقصود: لون
/// واحد لكل دور يمنع الواجهة من الصراخ بثلاثة ألوان في مكان واحد.
class AppColors {
  AppColors._();

  // ── الهوية ───────────────────────────────────────────────────────
  static const navy = Color(0xFF1F2A5E);
  static const navyDarker = Color(0xFF161E48);

  /// أعمق درجة — خلفيات الأبطال والتدرّجات، لا النصوص.
  static const navyDeep = Color(0xFF0E1433);

  /// أفتح درجة — الحدود والفواصل فوق الكحلي.
  static const navySoft = Color(0xFF33417F);

  // ── الفعل ────────────────────────────────────────────────────────
  static const coral = Color(0xFFF96167);

  /// درجة الضغط: زرٌّ لا يتغيّر تحت الإصبع يبدو معطّلاً.
  static const coralPressed = Color(0xFFE04B52);

  /// خلفية رقيقة للتنبيهات والشارات المرجانية على سطح فاتح.
  static const coralWash = Color(0xFFFFECEC);

  // ── الزينة ───────────────────────────────────────────────────────
  /// ذهبي فاتح — للنصوص والأيقونات **فوق الكحلي** فقط.
  static const gold = Color(0xFFF9E795);

  /// ذهبي غامق — البديل الوحيد المقروء فوق الأبيض.
  ///
  /// القيمة محسوبة لا مُقدَّرة: تباينها على الأبيض **٥٫٢:١** فتجتاز حدّ
  /// WCAG AA للنص العادي لا الكبير وحده، بهامش يحتمل فروق الحساب.
  /// (الفاتح تباينُه ١٫٢، ودرجتان أفتح جُرِّبتا فسقطتا عند ٢٫٦٥ و٤٫٤٧ —
  /// كشفهما اختبار التباين لا العين.)
  static const goldDeep = Color(0xFF8F650C);

  // ── دلالات ───────────────────────────────────────────────────────
  static const success = Color(0xFF1EA97C);
  static const warning = Color(0xFFE8A33D);
  static const danger = Color(0xFFD64550);

  // ── أسطح فاتحة ──────────────────────────────────────────────────
  static const surfaceLight = Color(0xFFF6F7FB);
  static const surfaceLightHigh = Color(0xFFFFFFFF);
  static const borderLight = Color(0xFFE3E6F0);

  // ── أسطح داكنة ──────────────────────────────────────────────────
  static const surfaceDark = Color(0xFF10142B);
  static const surfaceDarkHigh = Color(0xFF1A2143);
  static const borderDark = Color(0xFF2B3462);
}

/// أنصاف أقطار موحّدة — التفاوت العشوائي بين ١٢ و١٤ و١٦ في الشاشات
/// يجعل الواجهة تبدو مجمَّعة من مصادر شتّى.
class AppRadius {
  AppRadius._();
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 999.0;
}

/// سلّم مسافات ثابت: كل قيمة مضاعفة الأربعة.
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// طباعة عربية: ارتفاع السطر أسخى من الافتراضي اللاتيني.
///
/// حروف العربية ذات صعود ونزول أطول (ج، ط، ك) فسطرٌ بارتفاع ١٫٢ يجعل
/// النصّ متلاصقاً يصعب مسحه بالعين — ١٫٤ إلى ١٫٧ هو المريح.
TextTheme _arabicTextTheme(Color onSurface, Color muted) {
  TextStyle t(double size, FontWeight w, double height, {Color? color}) =>
      TextStyle(
        fontFamily: kFontFamily,
        fontSize: size,
        fontWeight: w,
        height: height,
        color: color ?? onSurface,
      );

  return TextTheme(
    displaySmall: t(30, FontWeight.w800, 1.28),
    headlineMedium: t(24, FontWeight.w800, 1.3),
    headlineSmall: t(20, FontWeight.w700, 1.32),
    titleLarge: t(18, FontWeight.w700, 1.35),
    titleMedium: t(16, FontWeight.w700, 1.4),
    titleSmall: t(14, FontWeight.w600, 1.45),
    bodyLarge: t(15.5, FontWeight.w400, 1.6),
    bodyMedium: t(14, FontWeight.w400, 1.6),
    bodySmall: t(12.5, FontWeight.w400, 1.55, color: muted),
    labelLarge: t(15, FontWeight.w700, 1.2),
    labelMedium: t(13, FontWeight.w600, 1.2),
    labelSmall: t(11.5, FontWeight.w600, 1.2, color: muted),
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: brightness,
    primary: isDark ? const Color(0xFF98A6E8) : AppColors.navy,
    secondary: AppColors.coral,
    tertiary: isDark ? AppColors.gold : AppColors.goldDeep,
    error: AppColors.danger,
    surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLightHigh,
    surfaceContainerHighest: isDark
        ? AppColors.surfaceDarkHigh
        : AppColors.surfaceLight,
  );

  final onSurface = scheme.onSurface;
  final muted = isDark ? const Color(0xFF9AA3C7) : const Color(0xFF666E8C);
  final border = isDark ? AppColors.borderDark : AppColors.borderLight;

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
    // خط عربي مضمَّن في التطبيق لا مُستعار من النظام: يضمن تشكيلاً وطباعة
    // عربية صحيحة على أندرويد وiOS والويب بالتساوي.
    fontFamily: kFontFamily,
    textTheme: _arabicTextTheme(onSurface, muted),
    splashFactory: InkSparkle.splashFactory,
  );

  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: base.scaffoldBackgroundColor,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? AppColors.surfaceDarkHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      height: 68,
      indicatorColor: AppColors.coral.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kFontFamily,
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? onSurface : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.coral
              : muted,
        ),
      ),
    ),

    // الزرّ الأساسي: مرجاني بظلّ من لونه نفسه — ظلّ رماديّ تحت زرّ ملوّن
    // يبدو متّسخاً، وظلّ من عائلة اللون يوحي بأن الزرّ يضيء لا يثقل.
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.coral.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.pressed)) {
            return AppColors.coralPressed;
          }
          return AppColors.coral;
        }),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        overlayColor: const WidgetStatePropertyAll(Colors.white24),
        elevation: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed) ? 1.0 : 4.0,
        ),
        shadowColor: WidgetStatePropertyAll(
          AppColors.coral.withValues(alpha: 0.45),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
        shape: const WidgetStatePropertyAll(shape),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: kFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        // حدّ ١٫٤ لا ١: الحدّ الشعرة يختفي على الشاشات عالية الكثافة.
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
        backgroundColor: isDark ? Colors.white10 : Colors.transparent,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        ),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: onSurface,
        highlightColor: AppColors.coral.withValues(alpha: 0.12),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.coral,
      foregroundColor: Colors.white,
      elevation: 4,
    ),

    cardTheme: CardThemeData(
      color: isDark ? AppColors.surfaceDarkHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border),
      ),
    ),

    // حقول الإدخال: سطح مملوء بلا حدّ صارخ، والتركيز يُعلَن بحدّ ملوّن
    // سميك — المستخدم يجب أن يعرف أين يكتب بنظرة لا بتخمين.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.surfaceDarkHigh : AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(fontFamily: kFontFamily, color: muted, fontSize: 14),
      labelStyle: TextStyle(
        fontFamily: kFontFamily,
        color: muted,
        fontSize: 14,
      ),
      floatingLabelStyle: TextStyle(
        fontFamily: kFontFamily,
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.8),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? AppColors.surfaceDarkHigh
          : AppColors.surfaceLight,
      selectedColor: scheme.primary,
      surfaceTintColor: Colors.transparent,
      checkmarkColor: Colors.white,
      side: BorderSide(color: border),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      secondaryLabelStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      shape: const StadiumBorder(),
    ),

    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),

    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 12.5,
        color: muted,
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppColors.surfaceDarkHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      titleTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: onSurface,
      ),
      contentTextStyle: TextStyle(
        fontFamily: kFontFamily,
        fontSize: 14,
        height: 1.6,
        color: onSurface,
      ),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.surfaceDarkHigh : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      showDragHandle: true,
    ),

    // شريط الرسائل عائم ومستدير: الملتصق بالحافة السفلية يغطّي أزرار
    // الشاشة تحته ويبدو نظاميًّا لا من التطبيق.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? AppColors.navySoft : AppColors.navy,
      contentTextStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.coral,
      linearMinHeight: 6,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.coral : null,
      ),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.navyDeep.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      textStyle: const TextStyle(
        fontFamily: kFontFamily,
        fontSize: 12,
        color: Colors.white,
      ),
    ),
  );
}

/// ألوان وأسطح مشتقة من السمة الحالية بدل الألوان الثابتة،
/// حتى تعمل الشاشات في الوضعين الفاتح والداكن.
extension AppSurfaces on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get cardBg =>
      isDarkMode ? AppColors.surfaceDarkHigh : AppColors.surfaceLight;

  Color get textMuted =>
      isDarkMode ? const Color(0xFF9AA3C7) : const Color(0xFF666E8C);

  Color get hairline =>
      isDarkMode ? AppColors.borderDark : AppColors.borderLight;

  /// ذهبيّ مقروء على السطح الحالي: الفاتح فوق الداكن والعكس.
  Color get goldOnSurface => isDarkMode ? AppColors.gold : AppColors.goldDeep;

  /// ظلّ ناعم موحّد للبطاقات المرفوعة — بديل ظلال متفرّقة بقيم مختلفة
  /// في كل شاشة.
  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDarkMode ? 0.34 : 0.07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  /// تدرّج الهوية لأسطح الأبطال (الشاشة الرئيسة، رؤوس الأقسام).
  LinearGradient get brandGradient => const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [AppColors.navy, AppColors.navyDeep],
  );
}
