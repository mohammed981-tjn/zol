import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// عنوان قسم: سطر علوي صغير ملوّن ثم العنوان.
///
/// السطر العلوي يحمل خطًّا مرجانيًّا قصيرًا قبله — علامة بصرية تربط
/// أقسام التطبيق كلها بلغة واحدة، وتمنع السطر الصغير من الذوبان في
/// النص المحيط كما كان.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.kicker, required this.title});

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              kicker,
              style: const TextStyle(
                color: AppColors.coral,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}
