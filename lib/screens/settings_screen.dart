import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';

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
            Container(
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
                      Icon(Icons.workspace_premium_outlined,
                          color: AppColors.gold),
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
                  const Text(
                    'مخرجات بعلامة مائية. رقِّ إلى الخطة الاحترافية (29\$ شهريًا) '
                    'لإزالة العلامة وفتح التوليد غير المحدود.',
                    style: TextStyle(color: Color(0xFFCADCFC), fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('الاشتراكات ستتوفر مع ربط بوابة الدفع'),
                        ),
                      );
                    },
                    child: const Text('الترقية للاحترافية'),
                  ),
                ],
              ),
            ),
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
}
