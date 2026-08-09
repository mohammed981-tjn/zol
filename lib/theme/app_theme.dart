import 'package:flutter/material.dart';

/// اسم الخط العربي المضمَّن. يُصرَّح صريحاً في كل TextStyle مبني يدوياً،
/// لأن TextStyle المُنشأ داخل ثيم مكوّن لا يرث fontFamily من ThemeData —
/// وإغفاله يُسقط النص على الخط الافتراضي فيظهر بطباعة مختلفة أو لا يظهر
/// أصلاً على الويب حين يتعذّر تحميل الخط الافتراضي.
const String kFontFamily = 'Cairo';

class AppColors {
  AppColors._();

  static const navy = Color(0xFF1F2A5E);
  static const navyDarker = Color(0xFF161E48);
  static const coral = Color(0xFFF96167);
  static const gold = Color(0xFFF9E795);
  static const cardBg = Color(0xFFF5F6FA);
  static const textDark = Color(0xFF1A1A2E);
  static const textMuted = Color(0xFF6B7280);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.coral,
      tertiary: AppColors.gold,
    ),
    scaffoldBackgroundColor: Colors.white,
    // خط عربي مضمَّن في التطبيق لا مُستعار من النظام: يضمن تشكيلاً وطباعة
    // عربية صحيحة على أندرويد وiOS والويب بالتساوي، ويوحّد الهوية مع ZadGo.
    fontFamily: kFontFamily,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: true,
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
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.navy),
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
