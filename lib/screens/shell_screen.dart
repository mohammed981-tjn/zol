import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'home_screen.dart';
import 'market_screen.dart';
import 'my_ads_screen.dart';
import 'templates_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

/// الهيكل الرئيسي بتنقل سفلي على نمط التطبيقات العالمية:
/// الرئيسية، السوق، القوالب (المعرض)، إعلاناتي (المكتبة)، طلباتي
/// (التتبع)، الإعدادات.
///
/// «السوق» في الموضع الثاني لا الأخير: التطبيق اسمه «سوق الدعاية
/// والإعلان الشامل»، ودفنُ السوق في آخر شريط التنقّل يجعل الاسم دعوى
/// لا وصفًا. وهو ثانٍ لا أوّل لأن الرئيسية تبقى مدخل الفعل (ولّد
/// إعلانًا)، والسوق ما يليه مباشرة.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          MarketScreen(),
          TemplatesScreen(),
          MyAdsScreen(),
          OrdersScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: l.navMarket,
          ),
          NavigationDestination(
            icon: const Icon(Icons.dashboard_customize_outlined),
            selectedIcon: const Icon(Icons.dashboard_customize),
            label: l.navTemplates,
          ),
          NavigationDestination(
            icon: const Icon(Icons.collections_outlined),
            selectedIcon: const Icon(Icons.collections),
            label: l.navMyAds,
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: l.navOrders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
