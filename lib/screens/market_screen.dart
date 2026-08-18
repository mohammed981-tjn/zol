import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../models/ad_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../services/provider_directory.dart';
import 'provider_screen.dart';
import 'provider_signup_screen.dart';
import 'storefront_screen.dart';

/// السوق — التبويب الذي كان ناقصًا.
///
/// اسم التطبيق «سوق الدعاية والإعلان الشامل»، وكان كل ما فيه: ولّد
/// إعلانًا ثم اطبعه. من أراد مصوّرًا لمنتجه أو مصمّم هوية أو من يدير
/// حملته خرج من التطبيق — ولا يعود غالبًا.
///
/// هنا الطرفان في مكان واحد: التاجر يتصفّح ويطلب، والمزوّد (والتاجر
/// نفسه) يعرض. وواجهة «متجري» في الأعلى تجعل التاجر عارضًا لا مشتريًا
/// فقط، وهو ما يجعل السوق سوقًا لا دليلًا.
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  // المتحكّم يملكه الـState لا الـbuild: إنشاؤه في build يفقد ما كُتب
  // مع كل إعادة رسم، وعدم التخلّص منه تسريب.
  final _search = TextEditingController();
  ServiceKind? _kind;
  String? _city;

  /// الدليل المعروض: يبدأ بالمحلّي فيُرسَم السوق فورًا، ثم يُستبدل بما
  /// على الخادم حين يصل. انتظارُ الشبكة قبل الرسم يعطي شاشة فارغة في
  /// تبويب رئيسي، والمحلّيون حقيقيون على كل حال.
  List<ServiceProvider> _providers = serviceProviders;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final list = await ProviderDirectory.approved();
    if (!mounted) return;
    setState(() => _providers = list);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final l = L.of(context);
    final results = filterProviders(
      kind: _kind,
      city: _city,
      query: _search.text,
      source: _providers,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.marketTitle),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProviderSignupScreen()),
              );
              // العودة من التسجيل قد تعني إدراجًا جديدًا معتمَدًا.
              await _refresh();
            },
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: Text(l.marketJoin),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StorefrontCard(state: state),
                  const SizedBox(height: AppSpacing.lg),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l.marketSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l.marketClearSearch,
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _kindChips()),
          SliverToBoxAdapter(child: _cityChips()),
          if (_kind != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Text(
                  _kind!.hint,
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                ),
              ),
            ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _Empty(onReset: _reset),
            )
          else
            SliverList.builder(
              itemCount: results.length,
              itemBuilder: (context, i) => Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  i == 0 ? AppSpacing.md : AppSpacing.sm,
                  AppSpacing.lg,
                  i == results.length - 1 ? AppSpacing.xl : 0,
                ),
                child: _ProviderCard(provider: results[i]),
              ),
            ),
        ],
      ),
    );
  }

  void _reset() => setState(() {
    _kind = null;
    _city = null;
    _search.clear();
  });

  Widget _kindChips() {
    final l = L.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _chip(
            label: l.marketAll,
            selected: _kind == null,
            onTap: () => setState(() => _kind = null),
          ),
          for (final k in ServiceKind.values)
            _chip(
              label: k.label,
              selected: _kind == k,
              onTap: () => setState(() => _kind = _kind == k ? null : k),
            ),
        ],
      ),
    );
  }

  Widget _cityChips() {
    final l = L.of(context);
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _chip(
            label: l.marketAllCities,
            selected: _city == null,
            onTap: () => setState(() => _city = null),
            dense: true,
          ),
          for (final c in providerCitiesOf(_providers))
            _chip(
              label: c,
              selected: _city == c,
              onTap: () => setState(() => _city = _city == c ? null : c),
              dense: true,
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool dense = false,
  }) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.sm),
    child: Center(
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: dense ? 12 : 13)),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: dense ? VisualDensity.compact : null,
      ),
    ),
  );
}

/// بطاقة «متجري» — مدخل التاجر إلى واجهة عرضه.
///
/// موضعها أعلى السوق مقصود: أول ما يراه التاجر في السوق أنّ **له** مكانًا
/// فيه، لا أنه زبون يتصفّح فقط.
class _StorefrontCard extends StatelessWidget {
  const _StorefrontCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final storeName = state.account?.storeName;
    final count = state.savedAds.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StorefrontScreen())),
        child: Ink(
          decoration: BoxDecoration(
            gradient: context.brandGradient,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              const Icon(Icons.storefront, color: Colors.white, size: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      storeName == null
                          ? l.storefrontMine
                          : l.storefrontNamed(storeName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? l.storefrontEmptyHint
                          : l.storefrontAdsCount(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFCADCFC),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});
  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProviderScreen(provider: provider)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            provider.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (provider.verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: context.goldOnSurface,
                            // الأيقونة وحدها لا تصل قارئ الشاشة.
                            semanticLabel: L.of(context).marketVerified,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _Rating(provider: provider),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${provider.kind.label} · ${provider.city}',
                style: TextStyle(fontSize: 12.5, color: context.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                provider.tagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    provider.onRequest
                        ? l.marketOnRequest
                        : l.marketPriceFrom(provider.priceFrom),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.goldOnSurface,
                      fontSize: 13.5,
                    ),
                  ),
                  if (provider.respondsInHours != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Icon(Icons.schedule, size: 14, color: context.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      l.marketRespondsIn(provider.respondsInHours!),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.provider});
  final ServiceProvider provider;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // تقييم واحد مقروء لقارئ الشاشة بدل نجمة ورقمين متفرّقين.
    return Semantics(
      label: l.marketRatingSemantics(
        provider.rating.toStringAsFixed(1),
        provider.reviews,
      ),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
          const SizedBox(width: 2),
          Text(
            provider.rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            '(${provider.reviews})',
            style: TextStyle(fontSize: 11.5, color: context.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 44, color: context.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text(
            L.of(context).marketEmptyTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            L.of(context).marketEmptyBody,
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onReset,
            child: Text(L.of(context).marketClearFilters),
          ),
        ],
      ),
    );
  }
}
