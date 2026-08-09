import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_circle.dart';
import 'create_ad/upload_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          children: [
            if (state.isLoggedIn) ...[
              Text(
                'مرحبًا، ${state.account!.name} 👋',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.gold, fontSize: 14),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 24),
            const IconCircle(
              icon: Icons.auto_fix_high,
              background: AppColors.coral,
              diameter: 96,
            ),
            const SizedBox(height: 32),
            const Text(
              'سوق الدعاية والإعلان الشامل',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AdCraft AI Marketplace',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 16,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'من الفكرة إلى الإعلان المطبوع والمُوصَّل خلال دقائق',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFCADCFC), fontSize: 15),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UploadDetailsScreen(),
                  ),
                );
              },
              child: const Text('أنشئ إعلانك الآن'),
            ),
            const SizedBox(height: 12),
            const Text(
              'معاينة فورية في أقل من 90 ثانية',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8B98C4), fontSize: 12),
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                _StatCard(
                  icon: Icons.collections_outlined,
                  value: '${state.savedAds.length}',
                  label: 'إعلان محفوظ',
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.local_shipping_outlined,
                  value: '${state.orders.length}',
                  label: 'طلب طباعة',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.navyDarker,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF8B98C4), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
