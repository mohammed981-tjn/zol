import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_role.dart';
import 'l10n/app_localizations.dart';
import 'screens/admin_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/print_shop_screen.dart';
import 'screens/shell_screen.dart';
import 'services/supabase_config.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// مدخل نكهة التاجر — الافتراضية.
Future<void> main() => bootstrap();

/// الإقلاع المشترك بين كل النكهات.
///
/// مفصولٌ عن [main] عمدًا: ملفّ مدخل نكهةٍ جديدة يصير سطرًا واحدًا
/// (`void main() => bootstrap(pinned: AppRole.printShop);`) بدل نسخ
/// التهيئة كلّها ثم افتراقها عن أصلها عند أوّل تعديل.
Future<void> bootstrap({AppRole? pinned}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  // استرجاع الإعلانات والطلبات والتفضيلات المحفوظة على الجهاز، وجلسة
  // حساب التاجر من Supabase إن كانت محفوظة من زيارة سابقة.
  final state = await AppState.load(client: Supabase.instance.client);
  runApp(ZolApp(state: state, pinnedRole: pinned));
}

class ZolApp extends StatelessWidget {
  const ZolApp({super.key, required this.state, this.pinnedRole});

  final AppState state;

  /// دورٌ يفرضه مدخل النكهة. `null` يترك الحسم لهوية الحساب.
  final AppRole? pinnedRole;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'zol',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: state.themeMode,
          // `null` ⇒ يتبع Flutter لغة الجهاز ويختار أقربها من
          // المدعومة. فرضُ `Locale('ar')` كان يجعل الاتجاه والنصّ
          // عربيَّين على كل جهاز مهما كانت لغته.
          locale: state.locale,
          supportedLocales: L.supportedLocales,
          localizationsDelegates: L.localizationsDelegates,
          home: _home(),
        ),
      ),
    );
  }

  /// الجذر يتبع الدور.
  ///
  /// وشاشة الترحيب تخصّ التاجر وحده: مطبعةٌ تفتح لوحتها لا تحتاج ثلاث
  /// صفحات تشرح توليد الإعلانات.
  Widget _home() {
    final role = resolveRole(
      pinned: pinnedRole,
      isShopOwner: state.isShopOwner,
      isAdmin: state.isPlatformAdmin,
    );
    return switch (role) {
      AppRole.admin => const AdminScreen(),
      AppRole.printShop => const PrintShopScreen(),
      AppRole.merchant => state.hasOnboarded
          ? const ShellScreen()
          : const OnboardingScreen(),
    };
  }
}
