import 'package:flutter/material.dart';

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
    fontFamily: 'Tajawal',
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
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
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
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'Tajawal',
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
