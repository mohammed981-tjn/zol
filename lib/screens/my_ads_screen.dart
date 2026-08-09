import 'package:flutter/material.dart';
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
    final ads = state.savedAds;
    final trashCount = state.trashedAds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعلاناتي'),
        actions: [
          IconButton(
            tooltip: 'سلة المهملات',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              );
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
                        'اضغط لفتح التصميم وإعادة تصديره أو طباعته',
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
                  label: 'نسخ النص',
                  button: true,
                  excludeSemantics: true,
                  onTap: () => _copyText(context, ad),
                  child: IconButton(
                    tooltip: 'نسخ النص',
                    onPressed: () => _copyText(context, ad),
                    icon: const Icon(Icons.copy_outlined, size: 20),
                  ),
                ),
                Semantics(
                  label: 'حذف',
                  button: true,
                  excludeSemantics: true,
                  onTap: () => _deleteAd(context, state, ad),
                  child: IconButton(
                    tooltip: 'حذف',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ النص الإعلاني')),
    );
  }

  void _deleteAd(BuildContext context, AppState state, GeneratedAd ad) {
    state.removeAd(ad);
    final trashed = state.trashedAds.first;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('نُقل الإعلان إلى سلة المهملات'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () => state.restoreAd(trashed),
        ),
      ),
    );
  }
}
