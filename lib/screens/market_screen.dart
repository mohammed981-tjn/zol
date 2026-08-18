import 'package:flutter/material.dart';

import '../models/ad_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'provider_screen.dart';
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

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final results = filterProviders(
      kind: _kind,
      city: _city,
      query: _search.text,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('السوق'),
        centerTitle: false,
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
                      hintText: 'ابحث عن مصوّر، مطبعة، مصمّم…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: 'مسح البحث',
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
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.textMuted,
                  ),
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

  Widget _kindChips() => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        _chip(
          label: 'الكل',
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

  Widget _cityChips() => SizedBox(
    height: 44,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        _chip(
          label: 'كل المدن',
          selected: _city == null,
          onTap: () => setState(() => _city = null),
          dense: true,
        ),
        for (final c in providerCities)
          _chip(
            label: c,
            selected: _city == c,
            onTap: () => setState(() => _city = _city == c ? null : c),
            dense: true,
          ),
      ],
    ),
  );

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
    final storeName = state.account?.storeName;
    final count = state.savedAds.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StorefrontScreen()),
        ),
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
                      storeName == null ? 'متجري' : 'متجر $storeName',
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
                          ? 'اعرض هويتك وأعمالك — ابدأ بحفظ إعلان'
                          : 'واجهة عرضك: $count ${count == 1 ? 'إعلان' : 'إعلانات'}',
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
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProviderScreen(provider: provider),
          ),
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
                            semanticLabel: 'موثّق',
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
                        ? 'حسب الطلب'
                        : 'من ${provider.priceFrom} ر.س',
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
                      'يردّ خلال ${provider.respondsInHours} ساعات',
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
    // تقييم واحد مقروء لقارئ الشاشة بدل نجمة ورقمين متفرّقين.
    return Semantics(
      label: 'التقييم ${provider.rating} من ٥، ${provider.reviews} مراجعة',
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
          const Text(
            'لا مزوّد يطابق بحثك',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'جرّب مدينة أخرى أو أزل المرشّحات',
            style: TextStyle(color: context.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onReset, child: const Text('إزالة المرشّحات')),
        ],
      ),
    );
  }
}
