import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/payment_config.dart';
import '../widgets/icon_circle.dart';
import '../widgets/section_header.dart';
import 'auth_screen.dart';
import 'payment/payment_flow.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionHeader(kicker: 'التفضيلات', title: 'إعدادات التطبيق'),
            const SizedBox(height: 20),
            _buildAccountSection(context, state),
            const SizedBox(height: 28),
            Text(
              'المظهر',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: context.scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('فاتح'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('داكن'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('النظام'),
                  icon: Icon(Icons.settings_suggest_outlined),
                ),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (modes) => state.setThemeMode(modes.first),
            ),
            const SizedBox(height: 28),
            _buildPlanCard(context, state),
            const SizedBox(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: context.textMuted),
              title: Text(
                'عن التطبيق',
                style: TextStyle(color: context.scheme.onSurface),
              ),
              subtitle: Text(
                'AdCraft AI Marketplace — نسخة تجريبية 1.0.0\n'
                'توليد إعلانات بالذكاء الاصطناعي، طباعة ميدانية، وتوصيل حتى الباب.',
                style: TextStyle(color: context.textMuted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, AppState state) {
    if (state.isPro) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium, color: AppColors.gold, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الخطة الاحترافية مفعّلة ✓',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'تصاميمك تُصدَّر بلا علامة مائية.',
                    style: TextStyle(color: Color(0xFFCADCFC), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: AppColors.gold),
              SizedBox(width: 8),
              Text(
                'الخطة المجانية',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'مخرجات بعلامة مائية. رقِّ إلى الخطة الاحترافية '
            '(${AppPaymentConfig.proMonthlyPriceSar.toStringAsFixed(0)} ر.س شهريًا) '
            'لإزالة العلامة وفتح التوليد غير المحدود.',
            style: const TextStyle(color: Color(0xFFCADCFC), fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => _upgradeToPro(context, state),
            child: const Text('الترقية للاحترافية'),
          ),
        ],
      ),
    );
  }

  Future<void> _upgradeToPro(BuildContext context, AppState state) async {
    final result = await startCardPayment(
      context,
      amountSar: AppPaymentConfig.proMonthlyPriceSar,
      description: 'اشتراك الخطة الاحترافية (شهري)',
    );
    if (!context.mounted) return;
    if (result != null && result.success) {
      state.activatePro();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل الخطة الاحترافية 🎉 — لا علامة مائية بعد الآن'),
        ),
      );
    } else if (result?.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result!.errorMessage!)),
      );
    }
  }

  Widget _buildAccountSection(BuildContext context, AppState state) {
    final account = state.account;
    if (account == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconCircle(
                  icon: Icons.storefront_outlined,
                  background: AppColors.navy,
                  diameter: 42,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'حساب التاجر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: context.scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'أنشئ حسابًا لربط إعلاناتك وطلباتك بمتجرك، '
              'وتجهيزًا للمزامنة السحابية بين أجهزتك.',
              style: TextStyle(color: context.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('تسجيل الدخول / إنشاء حساب'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const IconCircle(
            icon: Icons.storefront,
            background: AppColors.coral,
            diameter: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: context.scheme.onSurface,
                  ),
                ),
                Text(
                  '${account.storeName} • ${account.email}',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: state.logout,
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}
