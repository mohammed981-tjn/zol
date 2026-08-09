import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/payment_config.dart';
import '../widgets/icon_circle.dart';
import '../widgets/section_header.dart';
import 'auth_screen.dart';
import 'payment/payment_flow.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  /// يُستخدم في الاختبارات لتجاوز منتقي الشعار الأصلي للجهاز.
  static Future<Uint8List?> Function()? debugPickLogoOverride;

  /// ألوان علامة جاهزة للاختيار (نمط Canva Brand Kit).
  static const brandSwatches = [
    0xFF1F2A5E,
    0xFFB91D3A,
    0xFF00695C,
    0xFF6A1B9A,
    0xFFEF6C00,
    0xFF2E7D32,
    0xFF37474F,
    0xFF8D6E63,
  ];

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
            _buildBrandKitSection(context, state),
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

  Widget _buildBrandKitSection(BuildContext context, AppState state) {
    final logo = state.brandLogoBytes;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'هوية العلامة (Brand Kit)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'لونك وشعارك يُطبَّقان تلقائيًا على كل تصاميمك المولَّدة.',
            style: TextStyle(color: context.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // «افتراضي» يعيد تدرجات النبرة.
              _swatch(
                context,
                state,
                value: null,
                child: Icon(Icons.format_color_reset_outlined,
                    size: 18, color: context.textMuted),
              ),
              for (final color in brandSwatches)
                _swatch(
                  context,
                  state,
                  value: color,
                  child: state.brandColorValue == color
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (logo != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(logo, fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickLogo(context, state),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(logo == null ? 'رفع شعار المتجر' : 'تغيير الشعار'),
                ),
              ),
              if (logo != null)
                IconButton(
                  tooltip: 'إزالة الشعار',
                  onPressed: () => state.setBrandLogo(null),
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(
    BuildContext context,
    AppState state, {
    required int? value,
    required Widget child,
  }) {
    final isSelected = state.brandColorValue == value;
    return InkWell(
      key: ValueKey('brand-swatch-${value ?? 'none'}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => state.setBrandColor(value),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: value == null ? context.cardBg : Color(value),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  Future<void> _pickLogo(BuildContext context, AppState state) async {
    try {
      final bytes = await (debugPickLogoOverride ?? _pickLogoFromGallery)();
      if (bytes != null) state.setBrandLogo(bytes);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر اختيار الشعار — حاول مجددًا')),
      );
    }
  }

  static Future<Uint8List?> _pickLogoFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    return file?.readAsBytes();
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
