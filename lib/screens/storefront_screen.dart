import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../models/generated_ad.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/art_palette.dart';
import '../widgets/ad_design_preview.dart';
import '../widgets/art_backdrop.dart';

/// متجري — واجهة عرض التاجر.
///
/// كانت الإعلانات تُصنَع ثم تُدفن في «إعلاناتي»: مكتبة خاصة لا يراها
/// أحد. التاجر ينتج عملًا ولا مكان يعرضه فيه، وهذا نصف السوق الغائب.
///
/// هذه الصفحة تجمع هويته (لونه وشعاره واسم متجره) مع ما أنتجه في
/// واجهة واحدة قابلة للعرض. اللوحة الفنية مشتقّة من لون علامته نفسه،
/// فتبدو الواجهة امتدادًا لإعلاناته لا صفحةً غريبة عنها.
class StorefrontScreen extends StatelessWidget {
  const StorefrontScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final l = L.of(context);
    final ads = state.savedAds;
    // لون العلامة إن وُجد، وإلا كحليّ الهوية: الواجهة يجب أن تُعرض
    // حتى قبل أن يضبط التاجر هويته.
    final art = ArtPalette.from(state.brandColor ?? AppColors.navy);
    final storeName = state.account?.storeName;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            foregroundColor: art.ink,
            backgroundColor: art.deep,
            actions: [
              IconButton(
                tooltip: l.storefrontShare,
                onPressed: () => _share(context, storeName, ads.length),
                icon: const Icon(Icons.ios_share),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                storeName ?? l.storefrontMine,
                style: TextStyle(
                  color: art.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ArtBackdrop(
                    palette: art,
                    seed: (storeName ?? 'zol').hashCode & 0xFFFF,
                    style: BackdropStyle.mesh,
                  ),
                  if (state.brandLogoBytes != null)
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.memory(
                          state.brandLogoBytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _Identity(state: state, art: art),
            ),
          ),
          if (ads.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 44,
                      color: context.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l.storefrontEmptyTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l.storefrontEmptyBody,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  l.storefrontShowcase(ads.length),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                ),
                itemCount: ads.length,
                itemBuilder: (context, i) => _ShowcaseTile(ad: ads[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _share(BuildContext context, String? storeName, int count) {
    final l = L.of(context);
    // المشاركة الحقيقية (صورة الواجهة أو رابطها) تحتاج صفحة عامة على
    // الخادم؛ حتى تُبنى، لا نَعِد بما لا نفعل.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? l.storefrontShareEmpty
              : l.storefrontSharePending(storeName ?? l.storefrontMine),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.state, required this.art});
  final AppState state;
  final ArtPalette art;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final name = state.account?.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null)
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Pill(
              label: l.storefrontHarmony(art.scheme.label),
              color: art.base,
            ),
            if (state.brandColor != null)
              _Pill(label: l.storefrontBrandColor, color: state.brandColor!),
            _Pill(label: l.storefrontSupportColor, color: art.complement),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          // نفس القاعدة في كل مكان: الحبر يُقاس لا يُختار.
          color: ArtPalette.inkOn(color),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ShowcaseTile extends StatelessWidget {
  const _ShowcaseTile({required this.ad});
  final GeneratedAd ad;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: 1,
        child: ad.kind == AdKind.image
            ? AdDesignPreview(ad: ad)
            : ColoredBox(
                color: context.cardBg,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(ad.kind.icon, size: 20, color: context.textMuted),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          ad.headline,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
