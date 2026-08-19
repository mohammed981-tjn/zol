import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../models/ad_service.dart';
import 'create_ad/execute_screen.dart';
import '../state/app_state.dart';
import '../models/print_catalog.dart';
import '../models/generated_ad.dart';
import '../theme/app_palette_source.dart';
import '../theme/app_theme.dart';
import '../theme/art_palette.dart';
import '../widgets/art_backdrop.dart';
import '../widgets/quote_request_sheet.dart';

/// صفحة المزوّد — «كيف يعرض الشريك أعماله».
///
/// الرأس مرسوم بمحرّك الفن نفسه الذي يرسم الإعلانات: كل مزوّد يأخذ لوحة
/// لونية مشتقّة من اسمه، فيتميّز بصريًّا عن جاره في القائمة بلا أن يرفع
/// صورة غلاف. وهذا يربط السوق بقلب التطبيق بدل أن يبدو تبويبًا ملصوقًا
/// من تطبيق آخر.
class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key, required this.provider});

  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final art = paletteForProvider(provider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            foregroundColor: art.ink,
            backgroundColor: art.deep,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                provider.name,
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
                    seed: provider.id.hashCode & 0xFFFF,
                    style: backdropForKind(provider.kind),
                  ),
                  Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        56,
                      ),
                      child: _KindBadge(kind: provider.kind, art: art),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        provider.city,
                        style: TextStyle(color: context.textMuted),
                      ),
                      const Spacer(),
                      Semantics(
                        label: l.marketRatingSemantics(
                          provider.rating.toStringAsFixed(1),
                          provider.reviews,
                        ),
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Color(0xFFF5A623),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              provider.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l.providerReviewsCount(provider.reviews),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    provider.tagline,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PriceRow(provider: provider),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l.providerWorks,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (provider.kind == ServiceKind.printing)
                    // مزوّد الطباعة وحده يعرض كتالوجًا حقيقيًّا بأسعار
                    // فعلية وزرّ يطلب — بقيّة الأصناف تنتظر لوحة تسجيل
                    // المزوّدين على الخادم، ولا نُظهر لها ما لا نملكه.
                    _PrintCatalogList(art: art)
                  else
                    for (final work in provider.works)
                      _WorkTile(title: work, art: art),
                  const SizedBox(height: AppSpacing.xl),
                  if (provider.kind != ServiceKind.printing) ...[
                    FilledButton.icon(
                      onPressed: () => _requestQuote(context),
                      icon: const Icon(Icons.send_outlined),
                      label: Text(l.providerRequestQuote),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      // الصدق أهم من إيهام الجاهزية: الطلب لا يصل المزوّد
                      // حتى تُوصَل لوحة المزوّدين على الخادم، وإخفاء ذلك
                      // يجعل التاجر ينتظر ردًّا لا يأتي.
                      l.providerDisclaimer,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _requestQuote(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuoteRequestSheet(
        provider: provider,
        merchantName: AppStateScope.of(context).account?.storeName,
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind, required this.art});
  final ServiceKind kind;
  final ArtPalette art;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: art.complement,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          color: ArtPalette.inkOn(art.complement),
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.provider});
  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Row(
      children: [
        Expanded(
          child: _Fact(
            icon: Icons.payments_outlined,
            label: l.providerPrice,
            value: provider.onRequest
                ? l.marketOnRequest
                : l.marketPriceFrom(provider.priceFrom),
          ),
        ),
        if (provider.respondsInHours != null)
          Expanded(
            child: _Fact(
              icon: Icons.schedule,
              label: l.providerResponseTime,
              value: l.providerResponseHours(provider.respondsInHours!),
            ),
          ),
        if (provider.verified)
          Expanded(
            child: _Fact(
              icon: Icons.verified_outlined,
              label: l.providerStatus,
              value: l.marketVerified,
            ),
          ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: context.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _WorkTile extends StatelessWidget {
  const _WorkTile({required this.title, required this.art});
  final String title;
  final ArtPalette art;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: art.base.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.image_outlined, size: 20, color: art.base),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

/// كتالوج الطباعة الحقيقي داخل صفحة المزوّد.
///
/// هذا ما يجعل أوّل صنف في السوق حقيقيًّا بلا خادم: الأسعار والمقاسات
/// والكميّات هي التي يحسب بها التطبيق الفاتورة فعلًا (`print_catalog`)،
/// لا قائمة عرضٍ موازية تُكتب هنا وتتقادم. وكل صفّ يفتح مسار الطلب
/// نفسه الذي يفتحه زرّ «اطبعه وصلّه» — بالمنتج والمقاس مُختارَين سلفًا.
class _PrintCatalogList extends StatelessWidget {
  const _PrintCatalogList({required this.art});
  final ArtPalette art;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final product in printCatalog)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _ProductBlock(product: product, art: art),
          ),
        Text(
          // «لكل وحدة» لا «لكل بنر»: وحدة القياس تختلف بين منتج وآخر
          // (بنر واحد مقابل حزمة خمسين استيكرًا)، وكل بطاقة تعرض وحدتها.
          L
              .of(context)
              .printPricesNote(
                formatPrice(deliveryFee),
                (vatRate * 100).round(),
              ),
          style: TextStyle(fontSize: 12, color: context.textMuted),
        ),
      ],
    );
  }
}

class _ProductBlock extends StatelessWidget {
  const _ProductBlock({required this.product, required this.art});
  final PrintProduct product;
  final ArtPalette art;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.hairline),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(product.icon, size: 18, color: art.base),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  product.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                product.unitName,
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < product.sizes.length; i++)
            _SizeRow(product: product, sizeIndex: i),
        ],
      ),
    );
  }
}

class _SizeRow extends StatelessWidget {
  const _SizeRow({required this.product, required this.sizeIndex});
  final PrintProduct product;
  final int sizeIndex;

  @override
  Widget build(BuildContext context) {
    final size = product.sizes[sizeIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(size.label, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            formatPrice(size.unitPrice),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: context.goldOnSurface,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: () => _order(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              L.of(context).printOrder,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  /// الطباعة تحتاج تصميمًا. المكتبة هي مصدره الوحيد، فإن كانت فارغة
  /// نقول ذلك صراحةً بدل فتح شاشة طلب بلا ما يُطبَع فيها.
  void _order(BuildContext context) {
    final state = AppStateScope.of(context);
    final printable = state.savedAds
        .where((a) => a.kind == AdKind.image)
        .toList();

    if (printable.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L.of(context).printNeedsDesign)));
      return;
    }

    if (printable.length == 1) {
      _push(context, printable.first);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                L.of(context).printWhichDesign,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: printable.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    printable[i].headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(printable[i].brief.productName),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _push(context, printable[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, GeneratedAd ad) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExecuteScreen(
          ad: ad,
          isDigital: false,
          initialProduct: product,
          initialSizeIndex: sizeIndex,
        ),
      ),
    );
  }
}
