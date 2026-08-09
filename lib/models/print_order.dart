import 'package:flutter/material.dart';
import 'payment_result.dart';

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
    this.deliveryLat,
    this.deliveryLng,
    this.payMethod = PayMethod.cash,
    this.isPaid = false,
    this.paymentId,
    this.shopName,
    this.shopLat,
    this.shopLng,
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

  /// إحداثيات موقع التوصيل المختار على الخريطة (null إن اكتفى العميل
  /// بالعنوان النصي).
  final double? deliveryLat;
  final double? deliveryLng;

  final PayMethod payMethod;

  /// true فقط بعد تأكيد البوابة بمعرّف عملية (قاعدة zadgo2).
  final bool isPaid;
  final String? paymentId;

  /// المطبعة الشريكة المُسندة تلقائيًا (الأقرب لموقع التوصيل).
  final String? shopName;
  final double? shopLat;
  final double? shopLng;

  bool get hasDeliveryPoint => deliveryLat != null && deliveryLng != null;

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
    deliveryLat: deliveryLat,
    deliveryLng: deliveryLng,
    payMethod: payMethod,
    isPaid: isPaid,
    paymentId: paymentId,
    shopName: shopName,
    shopLat: shopLat,
    shopLng: shopLng,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'productLabel': productLabel,
    'sizeLabel': sizeLabel,
    'quantity': quantity,
    'subtotal': subtotal,
    'deliveryFee': deliveryFee,
    'vat': vat,
    'address': address,
    'status': status.index,
    'createdAt': createdAt.toIso8601String(),
    'deliveryLat': deliveryLat,
    'deliveryLng': deliveryLng,
    'payMethod': payMethod.index,
    'isPaid': isPaid,
    'paymentId': paymentId,
    'shopName': shopName,
    'shopLat': shopLat,
    'shopLng': shopLng,
  };

  factory PrintOrder.fromJson(Map<String, dynamic> json) => PrintOrder(
    id: json['id'] as String? ?? '',
    productLabel: json['productLabel'] as String? ?? '',
    sizeLabel: json['sizeLabel'] as String? ?? '',
    quantity: json['quantity'] as int? ?? 1,
    subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0,
    vat: (json['vat'] as num?)?.toDouble() ?? 0,
    address: json['address'] as String? ?? '',
    status: OrderStatus.values[json['status'] as int? ?? 0],
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    deliveryLat: (json['deliveryLat'] as num?)?.toDouble(),
    deliveryLng: (json['deliveryLng'] as num?)?.toDouble(),
    payMethod: PayMethod.values[json['payMethod'] as int? ?? 0],
    isPaid: json['isPaid'] as bool? ?? false,
    paymentId: json['paymentId'] as String?,
    shopName: json['shopName'] as String?,
    shopLat: (json['shopLat'] as num?)?.toDouble(),
    shopLng: (json['shopLng'] as num?)?.toDouble(),
  );
}
