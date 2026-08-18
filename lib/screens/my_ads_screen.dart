import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import '../models/generated_ad.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/icon_circle.dart';
import '../widgets/section_header.dart';
import 'create_ad/execute_screen.dart';
import 'trash_screen.dart';

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final l = L.of(context);
    final ads = state.savedAds;
    final trashCount = state.trashedAds.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navMyAds),
        actions: [
          IconButton(
            tooltip: l.myAdsTrash,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TrashScreen()));
            },
            icon: trashCount == 0
                ? const Icon(Icons.delete_outline)
                : Badge(
                    label: Text('$trashCount'),
                    child: const Icon(Icons.delete_outline),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: ads.isEmpty
            ? EmptyState(
                icon: Icons.collections_outlined,
                title: l.myAdsEmptyTitle,
                subtitle: l.myAdsEmptyBody,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  SectionHeader(kicker: l.myAdsKicker, title: l.myAdsTitle),
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
    final l = L.of(context);
    final d = ad.createdAt;

    // زرّا النسخ والحذف عنصران مستقلّان لا يقعان داخل شجرة InkWell فتح
    // التصميم — عنصر تفاعلي داخل عنصر تفاعلي آخر يجعل محرك الويب يُدمج
    // إتاحتهما في عقدة واحدة (البطاقة كلها) بدل أن يبقيا زرّين منفردَين
    // يصل إليهما قارئ الشاشة بالتنقل. الفصل البنيوي هنا حلّ عام يعمل في
    // كل محركات العرض، لا حلّ خاص بـ Semantics وحده.
    return Container(
      key: ValueKey('saved-ad-${ad.createdAt.microsecondsSinceEpoch}'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            // فتح الإعلان المحفوظ لإعادة تصديره أو طلب طباعته.
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExecuteScreen(ad: ad, isDigital: true),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                              style: TextStyle(
                                color: context.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
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
                      Icon(
                        Icons.touch_app_outlined,
                        size: 15,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        L.of(context).myAdsOpenHint,
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // [Semantics.label] صريح إلى جانب [tooltip]: تلميح الزر
                // وحده لا يُترجم إلى اسم إتاحة مقروء في محرك الويب
                // الحالي. و[onTap] هنا ضروري أيضًا — بلا حدث إتاحة فعلي
                // يُسقط محرك الوصولية (Accessibility Tree) العقدة كليًا
                // بصفتها غير قابلة للتفعيل رغم ظهورها في DOM.
                Semantics(
                  label: l.myAdsCopyText,
                  button: true,
                  excludeSemantics: true,
                  onTap: () => _copyText(context, ad),
                  child: IconButton(
                    tooltip: l.myAdsCopyText,
                    onPressed: () => _copyText(context, ad),
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                ),
                Semantics(
                  label: l.myAdsDelete,
                  button: true,
                  excludeSemantics: true,
                  onTap: () => _deleteAd(context, state, ad),
                  child: IconButton(
                    tooltip: l.myAdsDelete,
                    onPressed: () => _deleteAd(context, state, ad),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyText(BuildContext context, GeneratedAd ad) async {
    await Clipboard.setData(ClipboardData(text: ad.shareText));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L.of(context).myAdsCopied)));
  }

  void _deleteAd(BuildContext context, AppState state, GeneratedAd ad) {
    state.removeAd(ad);
    final trashed = state.trashedAds.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.of(context).myAdsMovedToTrash),
        action: SnackBarAction(
          label: L.of(context).actionUndo,
          onPressed: () => state.restoreAd(trashed),
        ),
      ),
    );
  }
}
