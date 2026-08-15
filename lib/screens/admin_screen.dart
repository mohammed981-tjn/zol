/// لوحة إدارة سوق الطباعة داخل التطبيق.
///
/// نقل للوحة الويب إلى شاشة أصيلة: نفس دوال القاعدة ونفس الصلاحيات، لكن
/// بلا متصفح ولا صفحة منفصلة. الفحص الأمني يقع في القاعدة لا هنا — إخفاء
/// الشاشة عن غير المشرف تحسينُ تجربةٍ لا حاجز.
library;

import 'package:flutter/material.dart';

import '../services/admin_api.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.api});

  final AdminApi? api;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminApi _api = widget.api ?? AdminApi();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإدارة'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'القيادة'),
              Tab(text: 'الطلبات'),
              Tab(text: 'التوليد'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DashboardTab(api: _api),
            _OrdersTab(api: _api),
            _GenerationsTab(api: _api),
          ],
        ),
      ),
    );
  }
}

/// يوحّد حالات التحميل والخطأ والفراغ، فلا تتكرر في كل تبويب.
class _Loader<T> extends StatefulWidget {
  const _Loader({
    required this.load,
    required this.builder,
    required this.emptyLabel,
    super.key,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  final String emptyLabel;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<T>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _Message(
              icon: Icons.error_outline,
              text: '${snap.error}',
              onRetry: _reload,
            );
          }
          final data = snap.data as T;
          if (data is List && data.isEmpty) {
            return _Message(icon: Icons.inbox_outlined, text: widget.emptyLabel);
          }
          return widget.builder(context, data, _reload);
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ],
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.api});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return _Loader<(AdminSummary, List<PrintShop>)>(
      emptyLabel: 'لا بيانات بعد.',
      load: () async => (
        await api.summary(),
        await api.shops(status: 'review'),
      ),
      builder: (context, data, reload) {
        final (s, pending) = data;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.7,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _Stat(label: 'طلبات مفتوحة', value: '${s.ordersOpen}'),
                _Stat(label: 'طلبات اليوم', value: '${s.ordersToday}'),
                _Stat(
                  label: 'عائد الشهر',
                  value: '${s.revenueMonth.toStringAsFixed(0)} ر.س',
                ),
                _Stat(
                  label: 'مبيعات الشهر',
                  value: '${s.gmvMonth.toStringAsFixed(0)} ر.س',
                ),
                _Stat(label: 'مطابع معتمدة', value: '${s.shopsApproved}'),
                _Stat(label: 'مناديب نشطون', value: '${s.couriersActive}'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'مطابع بانتظار المراجعة (${pending.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('لا طلبات انضمام معلّقة.'),
              )
            else
              ...pending.map(
                (shop) => Card(
                  child: ListTile(
                    title: Text(shop.name),
                    subtitle: Text(
                      [shop.city, shop.phone].whereType<String>().join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'اعتماد',
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () => _setStatus(
                            context, shop, 'approved', reload,
                          ),
                        ),
                        IconButton(
                          tooltip: 'رفض',
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () => _setStatus(
                            context, shop, 'rejected', reload,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    PrintShop shop,
    String status,
    VoidCallback reload,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.setShopStatus(shop.id, status);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'اعتُمدت ${shop.name}'
                : 'رُفضت ${shop.name}',
          ),
        ),
      );
      reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _statusLabels = <String, String>{
  'pending': 'بانتظار',
  'assigned': 'مُسندة',
  'printing': 'قيد الطباعة',
  'ready': 'جاهزة',
  'delivering': 'قيد التوصيل',
  'delivered': 'سُلّمت',
  'cancelled': 'أُلغيت',
  'refunded': 'مُستردّة',
};

/// الانتقالات المسموحة. القاعدة هي الحكم النهائي؛ هذه تمنع عرض خيار
/// سيُرفض على أي حال.
const _nextStatuses = <String, List<String>>{
  'pending': ['assigned', 'cancelled'],
  'assigned': ['printing', 'cancelled'],
  'printing': ['ready'],
  'ready': ['delivering'],
  'delivering': ['delivered'],
};

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.api});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return _Loader<List<AdminOrder>>(
      emptyLabel: 'لا طلبات بعد.',
      load: api.orders,
      builder: (context, orders, reload) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final o = orders[i];
          final next = _nextStatuses[o.status] ?? const <String>[];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.merchantName ?? 'تاجر',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text(_statusLabels[o.status] ?? o.status),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (o.productKind != null) o.productKind!,
                      '${o.quantity} نسخة',
                      '${o.grandTotal.toStringAsFixed(0)} ر.س',
                      if (!o.isPaid) 'غير مدفوع',
                    ].join(' · '),
                  ),
                  if (o.shopName != null)
                    Text(
                      'المطبعة: ${o.shopName}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (next.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: next
                          .map(
                            (to) => OutlinedButton(
                              onPressed: () =>
                                  _transition(context, o, to, reload),
                              child: Text(_statusLabels[to] ?? to),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _transition(
    BuildContext context,
    AdminOrder order,
    String to,
    VoidCallback reload,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.transitionOrder(order.id, to);
      messenger.showSnackBar(
        SnackBar(content: Text('صار الطلب: ${_statusLabels[to] ?? to}')),
      );
      reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _GenerationsTab extends StatelessWidget {
  const _GenerationsTab({required this.api});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return _Loader<List<GenerationEntry>>(
      emptyLabel: 'لا توليدات بعد.',
      load: () => api.generations(),
      builder: (context, items, reload) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final g = items[i];
          return Card(
            child: ExpansionTile(
              leading: Icon(
                g.failed ? Icons.error_outline : Icons.check_circle_outline,
                color: g.failed
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(g.merchant),
              subtitle: Text(
                [
                  if (g.model != null) g.model!,
                  if (g.costSar != null) '${g.costSar!.toStringAsFixed(3)} ر.س',
                  if (g.latencyMs != null) '${(g.latencyMs! / 1000).toStringAsFixed(1)} ث',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              children: [
                if (g.failed)
                  ListTile(
                    dense: true,
                    title: Text(g.errorCode ?? 'فشل بلا رمز'),
                    textColor: Theme.of(context).colorScheme.error,
                  )
                else
                  ...g.variants.map(
                    (v) => ListTile(
                      dense: true,
                      title: Text(v.headline),
                      subtitle: Text(
                        [
                          if (v.angle != null) v.angle!,
                          if (v.score != null) 'درجة ${v.score}',
                          if (v.cta != null) v.cta!,
                        ].join(' · '),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
