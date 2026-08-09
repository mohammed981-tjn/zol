import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/generated_ad.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/icon_circle.dart';
import '../widgets/section_header.dart';
import 'create_ad/execute_screen.dart';

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final ads = state.savedAds;

    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      body: SafeArea(
        child: ads.isEmpty
            ? const EmptyState(
                icon: Icons.collections_outlined,
                title: 'مكتبتك فارغة',
                subtitle:
                    'احفظ النسخ التي تعجبك من «شاشة السحر» لتجدها هنا جاهزة لإعادة الاستخدام أو الطباعة.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SectionHeader(
                    kicker: 'المكتبة',
                    title: 'إعلاناتك المحفوظة',
                  ),
                  const SizedBox(height: 16),
                  ...ads.map((ad) => _SavedAdCard(ad: ad)),
                ],
              ),
      ),
    );
  }
}

class _SavedAdCard extends StatelessWidget {
  const _SavedAdCard({required this.ad});

  final GeneratedAd ad;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final d = ad.createdAt;

    return InkWell(
      key: ValueKey('saved-ad-${ad.createdAt.microsecondsSinceEpoch}'),
      borderRadius: BorderRadius.circular(16),
      // فتح الإعلان المحفوظ لإعادة تصديره أو طلب طباعته.
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExecuteScreen(ad: ad, isDigital: true),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
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
              IconCircle(
                icon: ad.kind.icon,
                background: AppColors.coral,
                diameter: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.brief.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.scheme.onSurface,
                      ),
                    ),
                    Text(
                      '${ad.kind.label} • ${ad.brief.platform} • '
                      '${d.year}/${d.month}/${d.day}',
                      style:
                          TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'نسخ النص',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: ad.shareText),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ النص الإعلاني')),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: () => state.removeAd(ad),
                icon: const Icon(Icons.delete_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ad.headline,
            style: const TextStyle(
              color: AppColors.coral,
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ad.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.touch_app_outlined, size: 15, color: context.textMuted),
              const SizedBox(width: 5),
              Text(
                'اضغط لفتح التصميم وإعادة تصديره أو طباعته',
                style: TextStyle(color: context.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}
