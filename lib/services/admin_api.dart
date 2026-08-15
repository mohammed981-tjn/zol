/// واجهة لوحة الإدارة داخل التطبيق.
///
/// تنادي نفس دوال القاعدة التي تناديها لوحة الويب — لا مسار خلفيًّا موازيًا.
/// كل دالة إدارية تفحص `is_platform_admin` داخل القاعدة نفسها، فإخفاء
/// الشاشة في الواجهة تحسينٌ لتجربة الاستعمال لا حاجزٌ أمني: مستخدم عادي
/// ينادي الدالة مباشرة يُردّ من الخادم لا من هنا.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// خطأ إداري مفهوم للعرض، بلا تفاصيل تقنية تُربك المستخدم.
class AdminException implements Exception {
  const AdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdminSummary {
  const AdminSummary({
    required this.shopsPending,
    required this.shopsApproved,
    required this.ordersOpen,
    required this.ordersToday,
    required this.revenueMonth,
    required this.gmvMonth,
    required this.couriersActive,
  });

  final int shopsPending;
  final int shopsApproved;
  final int ordersOpen;
  final int ordersToday;
  final num revenueMonth;
  final num gmvMonth;
  final int couriersActive;

  factory AdminSummary.fromJson(Map<String, dynamic> j) => AdminSummary(
        shopsPending: (j['shops_pending'] as num?)?.toInt() ?? 0,
        shopsApproved: (j['shops_approved'] as num?)?.toInt() ?? 0,
        ordersOpen: (j['orders_open'] as num?)?.toInt() ?? 0,
        ordersToday: (j['orders_today'] as num?)?.toInt() ?? 0,
        revenueMonth: (j['revenue_month'] as num?) ?? 0,
        gmvMonth: (j['gmv_month'] as num?) ?? 0,
        couriersActive: (j['couriers_active'] as num?)?.toInt() ?? 0,
      );
}

class AdminOrder {
  const AdminOrder({
    required this.id,
    required this.status,
    required this.quantity,
    required this.grandTotal,
    required this.platformCut,
    required this.isPaid,
    this.productKind,
    this.merchantName,
    this.shopName,
    this.courierName,
    this.deliveryAddress,
    this.createdAt,
  });

  final String id;
  final String status;
  final int quantity;
  final num grandTotal;
  final num platformCut;
  final bool isPaid;
  final String? productKind;
  final String? merchantName;
  final String? shopName;
  final String? courierName;
  final String? deliveryAddress;
  final DateTime? createdAt;

  factory AdminOrder.fromJson(Map<String, dynamic> j) => AdminOrder(
        id: j['id'] as String,
        status: (j['status'] as String?) ?? 'unknown',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        grandTotal: (j['grand_total'] as num?) ?? 0,
        platformCut: (j['platform_cut'] as num?) ?? 0,
        isPaid: (j['is_paid'] as bool?) ?? false,
        productKind: j['product_kind'] as String?,
        merchantName: j['merchant_name'] as String?,
        shopName: j['shop_name'] as String?,
        courierName: j['courier_name'] as String?,
        deliveryAddress: j['delivery_address'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] as String?) ?? ''),
      );
}

class GenerationEntry {
  const GenerationEntry({
    required this.id,
    required this.merchant,
    required this.status,
    this.model,
    this.platform,
    this.costSar,
    this.tokensIn,
    this.tokensOut,
    this.latencyMs,
    this.errorCode,
    this.createdAt,
    this.variants = const [],
  });

  final String id;
  final String merchant;
  final String status;
  final String? model;
  final String? platform;
  final num? costSar;
  final int? tokensIn;
  final int? tokensOut;
  final int? latencyMs;
  final String? errorCode;
  final DateTime? createdAt;
  final List<GenerationVariant> variants;

  bool get failed => status != 'ok';

  factory GenerationEntry.fromJson(Map<String, dynamic> j) => GenerationEntry(
        id: (j['id'] ?? '').toString(),
        merchant: (j['merchant'] as String?) ?? 'تاجر',
        status: (j['status'] as String?) ?? 'ok',
        model: j['model'] as String?,
        platform: j['platform'] as String?,
        costSar: j['cost_sar'] as num?,
        tokensIn: (j['tokens_in'] as num?)?.toInt(),
        tokensOut: (j['tokens_out'] as num?)?.toInt(),
        latencyMs: (j['latency_ms'] as num?)?.toInt(),
        errorCode: j['error_code'] as String?,
        createdAt: DateTime.tryParse((j['created_at'] as String?) ?? ''),
        variants: ((j['variants'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GenerationVariant.fromJson)
            .toList(),
      );
}

class GenerationVariant {
  const GenerationVariant({
    required this.headline,
    this.angle,
    this.body,
    this.cta,
    this.score,
    this.fix,
  });

  final String headline;
  final String? angle;
  final String? body;
  final String? cta;
  final num? score;
  final String? fix;

  factory GenerationVariant.fromJson(Map<String, dynamic> j) =>
      GenerationVariant(
        headline: (j['headline'] as String?) ?? '',
        angle: j['angle'] as String?,
        body: j['body'] as String?,
        cta: j['cta'] as String?,
        score: j['score'] as num?,
        fix: j['fix'] as String?,
      );
}

class PrintShop {
  const PrintShop({
    required this.id,
    required this.name,
    required this.status,
    this.city,
    this.phone,
  });

  final String id;
  final String name;
  final String status;
  final String? city;
  final String? phone;

  factory PrintShop.fromJson(Map<String, dynamic> j) => PrintShop(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'مطبعة',
        status: (j['status'] as String?) ?? 'review',
        city: j['city'] as String?,
        phone: j['phone'] as String?,
      );
}

class AdminApi {
  AdminApi({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  /// يُقرأ من القاعدة لا من دور محفوظ محليًا — الصلاحية قد تُسحب في أي وقت.
  Future<bool> isAdmin() async {
    try {
      final res = await _db.rpc('is_platform_admin');
      return res == true;
    } on PostgrestException {
      return false;
    }
  }

  /// الدوال الإدارية تعيد `{ok:false, error:'admin_only'}` بدل رمي خطأ،
  /// فالنجاح الشكلي لا يكفي — لا بد من فحص `ok` قبل قراءة أي حقل.
  Map<String, dynamic> _unwrap(dynamic res) {
    if (res is! Map) throw const AdminException('ردّ غير متوقّع من الخادم.');
    final map = Map<String, dynamic>.from(res);
    if (map['ok'] == false) {
      final err = map['error'];
      throw AdminException(switch (err) {
        'admin_only' => 'هذه الشاشة لمشرفي المنصة فقط.',
        'not_authenticated' => 'سجّل الدخول أولًا.',
        _ => 'تعذّر إتمام العملية: $err',
      });
    }
    return map;
  }

  Future<AdminSummary> summary() async =>
      AdminSummary.fromJson(_unwrap(await _db.rpc('admin_summary')));

  Future<List<AdminOrder>> orders() async {
    final res = await _db.rpc('admin_order_list');
    if (res is! List) throw const AdminException('تعذّر جلب الطلبات.');
    return res
        .whereType<Map<String, dynamic>>()
        .map(AdminOrder.fromJson)
        .toList();
  }

  Future<List<GenerationEntry>> generations({int limit = 30}) async {
    final map = _unwrap(await _db.rpc('generation_feed', params: {
      'p_limit': limit,
    }));
    return ((map['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GenerationEntry.fromJson)
        .toList();
  }

  Future<List<PrintShop>> shops({String? status}) async {
    var q = _db.from('print_shops').select('id,name,status,city,phone');
    if (status != null) q = q.eq('status', status);
    final res = await q.order('created_at', ascending: false);
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map(PrintShop.fromJson)
        .toList();
  }

  Future<void> setShopStatus(String shopId, String status) async {
    _unwrap(await _db.rpc('admin_set_shop_status', params: {
      'p_shop_id': shopId,
      'p_status': status,
    }));
  }

  Future<void> assignOrder(
    String orderId, {
    required String shopId,
    String? courierId,
  }) async {
    _unwrap(await _db.rpc('print_order_assign', params: {
      'p_order_id': orderId,
      'p_shop_id': shopId,
      if (courierId != null) 'p_courier_id': courierId,
    }));
  }

  Future<void> transitionOrder(String orderId, String to, {String? note}) async {
    _unwrap(await _db.rpc('print_order_transition', params: {
      'p_order_id': orderId,
      'p_to': to,
      if (note != null && note.isNotEmpty) 'p_note': note,
    }));
  }
}
