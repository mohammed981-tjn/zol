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

class AppColors {
  AppColors._();

  static const navy = Color(0xFF1F2A5E);
  static const navyDarker = Color(0xFF161E48);
  static const coral = Color(0xFFF96167);
  static const gold = Color(0xFFF9E795);
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: brightness,
      primary: isDark ? const Color(0xFF98A6E8) : AppColors.navy,
      secondary: AppColors.coral,
      tertiary: AppColors.gold,
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF10142B) : Colors.white,
    // خط عربي مضمَّن في التطبيق لا مُستعار من النظام: يضمن تشكيلاً وطباعة
    // عربية صحيحة على أندرويد وiOS والويب بالتساوي.
    fontFamily: kFontFamily,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: base.scaffoldBackgroundColor,
      foregroundColor: base.colorScheme.onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: base.scaffoldBackgroundColor,
      indicatorColor: AppColors.coral.withValues(alpha: 0.16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: base.colorScheme.primary,
        side: BorderSide(color: base.colorScheme.primary),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: kFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

/// ألوان مساعدة مشتقة من السمة الحالية بدل الألوان الثابتة،
/// حتى تعمل الشاشات في الوضعين الفاتح والداكن.
extension AppSurfaces on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
  Color get cardBg => scheme.surfaceContainerHighest.withValues(
    alpha: Theme.of(this).brightness == Brightness.dark ? 0.55 : 1,
  );
  Color get textMuted => scheme.onSurfaceVariant;
}
