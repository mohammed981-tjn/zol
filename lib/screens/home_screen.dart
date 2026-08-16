import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/zol_logo.dart';
import 'create_ad/upload_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      backgroundColor: AppColors.navy,
      // تدرّج الهوية بدل الكحلي المسطّح: اللون الواحد الممتد على شاشة
      // كاملة يبدو ورقة مطبوعة، والتدرّج يعطي عمقاً بلا زخرفة زائدة.
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: context.brandGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            children: [
              if (state.isLoggedIn) ...[
                _WelcomeChip(name: state.account!.name),
                const SizedBox(height: AppSpacing.lg),
              ] else
                const SizedBox(height: AppSpacing.xl),
              const Center(child: ZolLogo(height: 92, color: Colors.white)),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'سوق الدعاية والإعلان الشامل',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'من الفكرة إلى الإعلان المطبوع والمُوصَّل خلال دقائق',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFCADCFC),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UploadDetailsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text('أنشئ إعلانك الآن'),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'معاينة فورية في أقل من 90 ثانية',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B98C4), fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  _StatCard(
                    icon: Icons.collections_outlined,
                    value: '${state.savedAds.length}',
                    label: 'إعلان محفوظ',
                  ),
                  const SizedBox(width: AppSpacing.md),
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
      ),
    );
  }
}

/// ترحيب في قرص زجاجي — سطرٌ عائم بلا حاوية كان يبدو منسيًّا في الفراغ.
class _WelcomeChip extends StatelessWidget {
  const _WelcomeChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Text(
          'مرحبًا، $name 👋',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
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
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          // زجاج فوق التدرّج لا لون صلب: البطاقة تنتمي للخلفية بدل أن
          // تُلصق عليها.
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.gold, size: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF9FAAD0), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
