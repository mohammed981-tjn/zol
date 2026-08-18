import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/supabase_config.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  // استرجاع الإعلانات والطلبات والتفضيلات المحفوظة على الجهاز، وجلسة
  // حساب التاجر من Supabase إن كانت محفوظة من زيارة سابقة.
  final state = await AppState.load(client: Supabase.instance.client);
  runApp(ZolApp(state: state));
}

class ZolApp extends StatelessWidget {
  const ZolApp({super.key, required this.state});

  final AppState state;

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
          home: state.hasOnboarded
              ? const ShellScreen()
              : const OnboardingScreen(),
        ),
      ),
    );
  }
}
