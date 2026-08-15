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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإدارة'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'القيادة'),
              Tab(text: 'الطلبات'),
              Tab(text: 'التوليد'),
              Tab(text: 'الشركاء'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DashboardTab(api: _api),
            _OrdersTab(api: _api),
            _GenerationsTab(api: _api),
            _PartnersTab(api: _api),
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

class _PartnersTab extends StatelessWidget {
  const _PartnersTab({required this.api});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return _Loader<List<Partner>>(
      // بلا شركاء تبقى الحاجة لزرّ الإنشاء قائمة، فلا يُكتفى برسالة فراغ.
      emptyLabel: '',
      load: api.partners,
      builder: (context, partners, reload) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _createPartner(context, reload),
          icon: const Icon(Icons.add),
          label: const Text('شريك جديد'),
        ),
        body: partners.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'لا شركاء بعد.\nأنشئ أولهم من الزرّ أدناه.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : _partnerList(context, partners, reload),
      ),
    );
  }

  Widget _partnerList(
    BuildContext context,
    List<Partner> partners,
    VoidCallback reload,
  ) {
    return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: partners.length,
        itemBuilder: (context, i) {
          final p = partners[i];
          final theme = Theme.of(context);
          final ratio = p.usageRatio;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(p.name, style: theme.textTheme.titleMedium),
                      ),
                      Switch(
                        value: p.isActive,
                        onChanged: (v) => _setActive(context, p, v, reload),
                      ),
                    ],
                  ),
                  Text(
                    p.slug,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.unlimited
                              ? 'الاستهلاك: ${p.used} — بلا حد'
                              : 'الاستهلاك: ${p.used} من ${p.quota}'
                                  ' · متبقٍ ${p.remaining}',
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('الحصة'),
                        onPressed: () => _editQuota(context, p, reload),
                      ),
                    ],
                  ),
                  if (ratio != null) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: ratio,
                      // الأحمر عند النفاد: الشريك يُردّ بـ429 عند هذا الحد.
                      color: ratio >= 1.0 ? theme.colorScheme.error : null,
                    ),
                  ],
                  if (p.costSar != null && p.costSar! > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'كلفة الشهر: ${p.costSar!.toStringAsFixed(2)} ر.س',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.keys.where((k) => !k.revoked).isEmpty
                              ? 'لا مفتاح فعّال'
                              : p.keys
                                  .where((k) => !k.revoked)
                                  .map((k) => '${k.prefix}…')
                                  .join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.key, size: 18),
                        label: const Text('مفتاح جديد'),
                        onPressed: () => _issueKey(context, p, reload),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
    );
  }

  /// إنشاء شريك: اسم ومُعرّف ورقمي وحساب تاجر وحصة.
  ///
  /// الشريك يُربط بحساب تاجر قائم لأن `generation_logs.merchant_id` إلزامي،
  /// فتُنسب توليداته وتُسعَّر وتظهر في السجل كما هي اليوم بلا تعديل جدول.
  Future<void> _createPartner(BuildContext context, VoidCallback reload) async {
    final messenger = ScaffoldMessenger.of(context);

    List<({String id, String name})> merchants;
    try {
      merchants = await api.candidateMerchants();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;

    if (merchants.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'لا حساب تاجر متاح. يسجّل الشريك حسابًا في التطبيق أولًا.',
          ),
        ),
      );
      return;
    }

    final nameCtl = TextEditingController();
    final slugCtl = TextEditingController();
    final quotaCtl = TextEditingController(text: '100');
    String? merchantId = merchants.first.id;
    String? error;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('شريك جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(labelText: 'اسم الشريك'),
                ),
                TextField(
                  controller: slugCtl,
                  decoration: const InputDecoration(
                    labelText: 'المُعرّف (حروف لاتينية وشرطات)',
                    hintText: 'sudagri',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: merchantId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'حساب التاجر'),
                  items: merchants
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setLocal(() => merchantId = v),
                ),
                TextField(
                  controller: quotaCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الحصة الشهرية',
                    helperText: '-1 تعني بلا حد',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final slug = slugCtl.text.trim();
                final quota = int.tryParse(quotaCtl.text.trim());
                // الفحص هنا لا في الخادم وحده: رسالة فورية أوضح من رحلة
                // ذهاب وإياب تنتهي بخطأ عام.
                if (nameCtl.text.trim().isEmpty) {
                  return setLocal(() => error = 'الاسم مطلوب.');
                }
                if (!RegExp(r'^[a-z0-9-]{2,40}$').hasMatch(slug)) {
                  return setLocal(
                    () => error = 'المُعرّف: حروف لاتينية صغيرة وأرقام وشرطات.',
                  );
                }
                if (quota == null || quota < -1) {
                  return setLocal(() => error = 'حصة غير صالحة.');
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || merchantId == null) return;

    try {
      await api.createPartner(
        name: nameCtl.text.trim(),
        slug: slugCtl.text.trim(),
        merchantId: merchantId!,
        quota: int.parse(quotaCtl.text.trim()),
      );
      messenger.showSnackBar(
        SnackBar(content: Text('أُنشئ ${nameCtl.text.trim()} — أصدر له مفتاحًا')),
      );
      reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editQuota(
    BuildContext context,
    Partner p,
    VoidCallback reload,
  ) async {
    final controller = TextEditingController(
      text: p.unlimited ? '' : '${p.quota}',
    );
    var unlimited = p.unlimited;

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('حصة ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('بلا حد'),
                value: unlimited,
                onChanged: (v) => setLocal(() => unlimited = v),
              ),
              TextField(
                controller: controller,
                enabled: !unlimited,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'توليدة في الشهر',
                  helperText: 'تُصفَّر مع بداية كل شهر ميلادي',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (unlimited) return Navigator.pop(ctx, -1);
                final v = int.tryParse(controller.text.trim());
                if (v == null || v < 0) return;
                Navigator.pop(ctx, v);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.setPartnerQuota(p.id, result);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result < 0
                ? 'صارت حصة ${p.name} بلا حد'
                : 'صارت حصة ${p.name} $result شهريًا',
          ),
        ),
      );
      reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _setActive(
    BuildContext context,
    Partner p,
    bool active,
    VoidCallback reload,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.setPartnerActive(p.id, active);
      messenger.showSnackBar(
        SnackBar(content: Text(active ? 'أُعيد ${p.name}' : 'أُوقف ${p.name}')),
      );
      reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _issueKey(
    BuildContext context,
    Partner p,
    VoidCallback reload,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    String key;
    try {
      key = await api.issuePartnerKey(p.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;

    // يُعرض مرة واحدة: المخزَّن تجزئته لا نصّه، فإغلاق الحوار يفقده أبداً.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انسخه الآن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('لن يُعرض هذا المفتاح مرة أخرى.'),
            const SizedBox(height: 12),
            SelectableText(
              key,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('نسختُه'),
          ),
        ],
      ),
    );
    reload();
  }
}
