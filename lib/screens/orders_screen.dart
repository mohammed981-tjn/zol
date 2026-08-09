import 'package:flutter/material.dart';
import '../models/print_catalog.dart';
import '../models/print_order.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import 'order_map_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final orders = state.orders;

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: SafeArea(
        child: orders.isEmpty
            ? const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'لا توجد طلبات بعد',
                subtitle:
                    'عند اختيار «اطبعه وصلّه» بعد توليد إعلانك، سيظهر الطلب هنا مع خط زمني لتتبع حالته.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const SectionHeader(
                    kicker: 'التتبع',
                    title: 'حالة طلبات الطباعة',
                  ),
                  const SizedBox(height: 16),
                  ...orders.map((order) => _OrderCard(order: order)),
                ],
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PrintOrder order;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Material(
          type: MaterialType.transparency,
          child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(order.status.icon, color: AppColors.coral),
          title: Text(
            '${order.productLabel} — ${order.id}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: context.scheme.onSurface,
            ),
          ),
          subtitle: Text(
            '${order.sizeLabel} × ${order.quantity} • ${formatPrice(order.total)}',
            style: TextStyle(color: context.textMuted, fontSize: 12.5),
          ),
          trailing: _StatusChip(status: order.status),
          children: [
            _OrderTimeline(status: order.status),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'التوصيل إلى: ${order.address}\n'
                '${order.shopName != null ? 'المطبعة: ${order.shopName}\n' : ''}'
                '${order.isPaid ? 'مدفوع بالبطاقة ✓' : 'الدفع عند الاستلام'}',
                style: TextStyle(color: context.textMuted, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (order.hasDeliveryPoint)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderMapScreen(order: order),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('عرض على الخريطة'),
                  ),
                const Spacer(),
                if (order.status != OrderStatus.delivered)
                  TextButton.icon(
                    onPressed: () => state.advanceOrder(order),
                    icon: const Icon(Icons.fast_forward_outlined, size: 18),
                    label: const Text('محاكاة التقدم (تجريبي)'),
                  ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final delivered = status == OrderStatus.delivered;
    final color = delivered ? const Color(0xFF2E7D32) : AppColors.coral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// خط زمني لحالة الطلب على نمط تطبيقات التوصيل العالمية.
class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: OrderStatus.values.map((step) {
        final reached = step.index <= status.index;
        final isLast = step == OrderStatus.values.last;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  reached ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: reached ? AppColors.coral : context.textMuted,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 20,
                    color: step.index < status.index
                        ? AppColors.coral
                        : context.textMuted.withValues(alpha: 0.3),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                step.label,
                style: TextStyle(
                  color: reached ? context.scheme.onSurface : context.textMuted,
                  fontWeight: reached ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
