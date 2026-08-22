import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// حالة الفراغ — أيقونة رمادية وحيدة كانت تبدو عطلًا لا حالةً طبيعية.
///
/// الأيقونة الآن داخل قرص ملوّن خفيف، ويمكن للشاشة أن تعرض معها إجراءً
/// يخرج المستخدم من الفراغ بدل أن يتركه أمامه.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// زرّ اختياري (مثل «أنشئ أول إعلان») يُعرض أسفل الوصف.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.coral.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.coral),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
