import 'package:flutter/material.dart';
import '../models/generated_ad.dart';
import '../models/trashed_ad.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/icon_circle.dart';
import '../widgets/section_header.dart';

/// سلة مهملات الإعلانات — تحمي التاجر من فقدان عمله بضغطة حذف خاطئة.
/// كل عنصر يُحذف نهائيًا تلقائيًا بعد [TrashedAd.retentionDays] يومًا.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final items = state.trashedAds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المهملات'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmEmptyTrash(context, state),
              child: const Text('إفراغ السلة'),
            ),
        ],
      ),
      body: SafeArea(
        child: items.isEmpty
            ? const EmptyState(
                icon: Icons.delete_outline,
                title: 'سلة المهملات فارغة',
                subtitle:
                    'الإعلانات التي تحذفها من «إعلاناتي» تبقى هنا لمدة '
                    '${TrashedAd.retentionDays} يومًا قبل حذفها نهائيًا،\n'
                    'وتقدر تسترجعها في أي وقت قبل ذلك.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SectionHeader(
                    kicker: 'استعادة أو حذف نهائي',
                    title: '${items.length} إعلان في السلة',
                  ),
                  const SizedBox(height: 16),
                  ...items.map((item) => _TrashedAdCard(item: item)),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إفراغ السلة نهائيًا؟'),
        content: Text(
          'سيُحذف ${state.trashedAds.length} إعلان نهائيًا ولا يمكن التراجع.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إفراغ نهائيًا'),
          ),
        ],
      ),
    );
    if (confirmed == true) state.emptyTrash();
  }
}

class _TrashedAdCard extends StatelessWidget {
  const _TrashedAdCard({required this.item});

  final TrashedAd item;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final ad = item.ad;
    final days = item.daysRemaining;

    return Container(
      key: ValueKey('trashed-ad-${ad.createdAt.microsecondsSinceEpoch}'),
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
                background: context.textMuted,
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
                      days <= 0
                          ? 'سيُحذف نهائيًا قريبًا'
                          : 'يُحذف نهائيًا خلال $days يومًا',
                      style: TextStyle(
                        color: days <= 3 ? AppColors.coral : context.textMuted,
                        fontSize: 12,
                        fontWeight: days <= 3 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => state.restoreAd(item),
                  icon: const Icon(Icons.restore_outlined, size: 18),
                  label: const Text('استعادة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => state.permanentlyDeleteAd(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: AppColors.coral),
                  ),
                  icon: const Icon(Icons.delete_forever_outlined, size: 18),
                  label: const Text('حذف نهائي'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
