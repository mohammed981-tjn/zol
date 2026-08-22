import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/print_order.dart';
import '../theme/app_theme.dart';

/// خريطة متابعة الطلب للعميل — بنية الشاشة منقولة من zadgo2
/// (فرع split-customer). موقع السائق حاليًا **محاكاة** تتحرك من المطبعة
/// نحو العميل؛ يُستبدل لاحقًا ببث موقع حقيقي من تطبيق السائق عبر الخادم.
class OrderMapScreen extends StatefulWidget {
  const OrderMapScreen({super.key, required this.order});

  final PrintOrder order;

  @override
  State<OrderMapScreen> createState() => _OrderMapScreenState();
}

class _OrderMapScreenState extends State<OrderMapScreen> {
  final MapController _mapController = MapController();
  Timer? _driverTimer;

  /// نسبة تقدم السائق بين المطبعة والعميل (محاكاة).
  double _progress = 0.15;

  PrintOrder get order => widget.order;

  LatLng get _delivery => LatLng(order.deliveryLat!, order.deliveryLng!);

  /// موقع المطبعة المُسندة للطلب (الأقرب لموقع العميل)، مع إزاحة
  /// افتراضية كاحتياط للطلبات القديمة التي بلا مطبعة مسندة.
  LatLng get _printShop => order.shopLat != null && order.shopLng != null
      ? LatLng(order.shopLat!, order.shopLng!)
      : LatLng(_delivery.latitude + 0.014, _delivery.longitude - 0.011);

  bool get _driverMoving => order.status == OrderStatus.shipping;

  LatLng get _driverPosition => LatLng(
    _printShop.latitude +
        (_delivery.latitude - _printShop.latitude) * _progress,
    _printShop.longitude +
        (_delivery.longitude - _printShop.longitude) * _progress,
  );

  @override
  void initState() {
    super.initState();
    if (_driverMoving) {
      _driverTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _progress = (_progress + 0.012).clamp(0, 0.96));
      });
    }
  }

  @override
  void dispose() {
    _driverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: _printShop,
        width: 60,
        height: 60,
        child: _pin(icon: Icons.print_outlined, color: Colors.orange),
      ),
      Marker(
        point: _delivery,
        width: 60,
        height: 60,
        child: _pin(icon: Icons.location_on, color: AppColors.coral),
      ),
      if (_driverMoving)
        Marker(
          point: _driverPosition,
          width: 50,
          height: 50,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.navy,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('متابعة الطلب')),
      body: Column(
        children: [
          _statusBanner(),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _delivery,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.zol.app',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [_printShop, _delivery],
                          strokeWidth: 4,
                          color: AppColors.coral.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: () => _mapController.move(_delivery, 15),
                    child: const Icon(Icons.my_location, color: AppColors.navy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final (text, icon) = switch (order.status) {
      OrderStatus.received => (
        'الطلب لدى المطبعة وسيبدأ تجهيزه',
        Icons.receipt_long_outlined,
      ),
      OrderStatus.printing => (
        'مطبوعاتك قيد الطباعة الآن',
        Icons.print_outlined,
      ),
      OrderStatus.shipping => ('السائق في طريقه إليك', Icons.delivery_dining),
      OrderStatus.delivered => ('تم تسليم طلبك بنجاح', Icons.done_all_rounded),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.coral.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(icon, color: AppColors.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$text • ${order.productLabel} (${order.id})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pin({required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
