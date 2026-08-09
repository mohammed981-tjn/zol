import 'package:flutter/material.dart';

enum OrderStatus { received, printing, shipping, delivered }

extension OrderStatusInfo on OrderStatus {
  String get label => switch (this) {
    OrderStatus.received => 'تم استلام الطلب',
    OrderStatus.printing => 'قيد الطباعة',
    OrderStatus.shipping => 'في الطريق إليك',
    OrderStatus.delivered => 'تم التسليم',
  };

  IconData get icon => switch (this) {
    OrderStatus.received => Icons.receipt_long_outlined,
    OrderStatus.printing => Icons.print_outlined,
    OrderStatus.shipping => Icons.local_shipping_outlined,
    OrderStatus.delivered => Icons.check_circle_outline,
  };
}

class PrintOrder {
  const PrintOrder({
    required this.id,
    required this.productLabel,
    required this.sizeLabel,
    required this.quantity,
    required this.subtotal,
    required this.deliveryFee,
    required this.vat,
    required this.address,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String productLabel;
  final String sizeLabel;
  final int quantity;
  final double subtotal;
  final double deliveryFee;
  final double vat;
  final String address;
  final OrderStatus status;
  final DateTime createdAt;

  double get total => subtotal + deliveryFee + vat;

  PrintOrder copyWith({OrderStatus? status}) => PrintOrder(
    id: id,
    productLabel: productLabel,
    sizeLabel: sizeLabel,
    quantity: quantity,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    vat: vat,
    address: address,
    status: status ?? this.status,
    createdAt: createdAt,
  );
}
