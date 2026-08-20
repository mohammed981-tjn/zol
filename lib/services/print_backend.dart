/// شبكة الطباعة على الخادم — المطابع ومنتجاتها والطلب وملفّه.
///
/// كان طلب الطباعة يعيش في `SharedPreferences` وحدها ولا يغادر الجهاز
/// **حتى المدفوع بالبطاقة**: تُقبض البطاقة، ويُكتب الطلب في هاتف التاجر،
/// ولا يعلم به خادمٌ ولا مطبعة. فمن أعاد تثبيت التطبيق فقد طلبًا دفع
/// ثمنه، ولوحة الإدارة المنشورة تعرض جدولًا فارغًا منذ بُنيت.
///
/// والبنية الخلفية كانت جاهزة منذ زمن ولم يُنادَ عليها: جدول `print_orders`
/// بعموده `artwork_url`، و`print_shops` بحساب مالكها، ودوالّ `print_order_quote`
/// و`print_order_create` و`print_order_transition`. الفجوة كلّها هنا.
///
/// **والسعر يأتي من الخادم لا يُحسب هنا.** هذا ليس تفضيلًا معماريًّا:
/// التطبيق كان يجمع الضريبة **فوق** الإجمالي والخادم يعدّها **مشمولة
/// فيه**، فطلبُ بنرين يُقبض بـ‎٢٣٥٫٧٥‎ ويُسجَّل بـ‎٢٠٥٫٠٠‎ — فرقٌ في كل
/// طلب، ودفاتر لا تتّزن. فمن يحسب المال هو من يسجّله.
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/print_shop.dart' show distanceKm;

/// مطبعة كما يعرفها الخادم.
class ShopRow {
  const ShopRow({
    required this.id,
    required this.name,
    this.city,
    this.phone,
    this.lat,
    this.lng,
    this.minTurnaroundHours,
  });

  final String id;
  final String name;
  final String? city;
  final String? phone;
  final double? lat;
  final double? lng;
  final int? minTurnaroundHours;

  bool get hasLocation => lat != null && lng != null;

  factory ShopRow.fromJson(Map<String, dynamic> j) => ShopRow(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    city: j['city'] as String?,
    phone: j['phone'] as String?,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    minTurnaroundHours: (j['min_turnaround_hours'] as num?)?.toInt(),
  );
}

/// منتج مطبعة بسعره — المصدر الوحيد للسعر.
class ProductRow {
  const ProductRow({
    required this.id,
    required this.shopId,
    required this.kind,
    required this.title,
    required this.unitPrice,
    this.minQty = 1,
    this.turnaroundHours,
    this.size,
  });

  final String id;
  final String shopId;

  /// `banner` · `flyer` · `sticker` · `card` · `roll_up` · `poster` · `menu`
  final String kind;
  final String title;
  final double unitPrice;
  final int minQty;
  final int? turnaroundHours;

  /// المقاس كما خزّنته المطبعة في `specs`.
  final String? size;

  factory ProductRow.fromJson(Map<String, dynamic> j) {
    final specs = (j['specs'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ProductRow(
      id: j['id'] as String,
      shopId: j['shop_id'] as String,
      kind: (j['kind'] as String?) ?? '',
      title: (j['title'] as String?) ?? '',
      unitPrice: (j['unit_price'] as num?)?.toDouble() ?? 0,
      minQty: (j['min_qty'] as num?)?.toInt() ?? 1,
      turnaroundHours: (j['turnaround_hours'] as num?)?.toInt(),
      size: specs['size'] as String?,
    );
  }
}

/// تسعيرة الخادم. `vatIncluded` **داخل** [grandTotal] لا فوقه.
class PrintQuote {
  const PrintQuote({
    required this.itemsTotal,
    required this.deliveryFee,
    required this.vatIncluded,
    required this.grandTotal,
    this.turnaroundHours,
  });

  final double itemsTotal;
  final double deliveryFee;
  final double vatIncluded;
  final double grandTotal;
  final int? turnaroundHours;

  factory PrintQuote.fromJson(Map<String, dynamic> j) => PrintQuote(
    itemsTotal: (j['items_total'] as num?)?.toDouble() ?? 0,
    deliveryFee: (j['delivery_fee'] as num?)?.toDouble() ?? 0,
    vatIncluded: (j['vat_included'] as num?)?.toDouble() ?? 0,
    grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0,
    turnaroundHours: (j['turnaround_hours'] as num?)?.toInt(),
  );
}

/// مآل محاولة إنشاء الطلب — أربعة صريحة لا نجاحٌ وصمت.
enum OrderOutcome {
  /// وصل الطلب ومعه ملفّه، وله رقم على الخادم.
  created,

  /// لا جلسة: الطلب يحتاج حسابًا ليُنسب إلى صاحبه.
  needsAccount,

  /// الشبكة أو الخادم متعثّر — الطلب لم يصل، والمحاولة تُعاد.
  offline,

  /// الخادم رفض بسبب مفهوم (مطبعة موقوفة، كمية دون الحدّ الأدنى…).
  rejected,
}

class OrderResult {
  const OrderResult(this.outcome, {this.orderId, this.reason, this.quote});

  final OrderOutcome outcome;
  final String? orderId;

  /// رمز الرفض كما أعاده الخادم — يُترجَم للعرض، ويُسجَّل كما هو.
  final String? reason;

  /// ما سجّله الخادم فعلًا من مال. يُقارَن بما عُرض على التاجر.
  final PrintQuote? quote;

  bool get ok => outcome == OrderOutcome.created;
}

/// الواجهة التي يعتمدها التطبيق — تُزيَّف في الاختبار بلا شبكة.
abstract class PrintBackend {
  /// المطابع المعتمدة المفتوحة.
  Future<List<ShopRow>> shops();

  /// منتجات مطبعة بعينها.
  Future<List<ProductRow>> products(String shopId);

  /// تسعيرة الخادم قبل القبض. `null` يعني تعذّر التسعير.
  Future<PrintQuote?> quote({
    required String shopId,
    required String productId,
    required int quantity,
  });

  /// يرفع ملفّ التصميم ويعيد رابطه العامّ. `null` يعني تعذّر الرفع.
  Future<String?> uploadArtwork(Uint8List png);

  Future<OrderResult> createOrder({
    required String shopId,
    required String productId,
    required int quantity,
    required String address,
    double? lat,
    double? lng,
    String? artworkUrl,
    String? artworkNotes,
    Map<String, dynamic>? specs,
    String paymentMethod = 'cash',
  });

  /// يربط الطلب بعملية الدفع. لا يُعلن الدفع — الخادم وحده يفعل.
  Future<bool> attachPayment(String orderId, String paymentRef);
}

/// التنفيذ فوق Supabase.
class SupabasePrintBackend implements PrintBackend {
  SupabasePrintBackend(this._db);

  final SupabaseClient _db;

  String? get _uid => _db.auth.currentUser?.id;

  @override
  Future<List<ShopRow>> shops() async {
    try {
      final rows = await _db
          .from('print_shops')
          .select('id,name,city,phone,lat,lng,min_turnaround_hours')
          .eq('status', 'approved')
          .eq('is_open', true)
          .order('name');
      return [
        for (final r in rows) ShopRow.fromJson(r),
      ];
    } catch (_) {
      // شبكة متعثّرة تعني «لا مطابع الآن» لا انهيارًا: الشاشة تعرض
      // مخرجًا صريحًا، ولا تسقط في وجه التاجر.
      return const [];
    }
  }

  @override
  Future<List<ProductRow>> products(String shopId) async {
    try {
      final rows = await _db
          .from('print_products')
          .select('id,shop_id,kind,title,specs,unit_price,min_qty,turnaround_hours')
          .eq('shop_id', shopId)
          .eq('is_active', true)
          .order('unit_price');
      return [
        for (final r in rows) ProductRow.fromJson(r),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PrintQuote?> quote({
    required String shopId,
    required String productId,
    required int quantity,
  }) async {
    try {
      final res = await _db.rpc(
        'print_order_quote',
        params: {
          'p_shop_id': shopId,
          'p_product_id': productId,
          'p_quantity': quantity,
        },
      );
      final map = (res as Map?)?.cast<String, dynamic>();
      if (map == null || map['ok'] == false) return null;
      return PrintQuote.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> uploadArtwork(Uint8List png) async {
    final uid = _uid;
    if (uid == null) return null;
    // المسار يبدأ بمعرّف صاحبه: سياسة السطل تشترط ذلك، فلا يكتب تاجر
    // فوق تصميم تاجر آخر قبل أن يُطبع.
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.png';
    try {
      await _db.storage.from('artwork').uploadBinary(
        path,
        png,
        fileOptions: const FileOptions(contentType: 'image/png'),
      );
      return _db.storage.from('artwork').getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OrderResult> createOrder({
    required String shopId,
    required String productId,
    required int quantity,
    required String address,
    double? lat,
    double? lng,
    String? artworkUrl,
    String? artworkNotes,
    Map<String, dynamic>? specs,
    String paymentMethod = 'cash',
  }) async {
    if (_uid == null) return const OrderResult(OrderOutcome.needsAccount);
    try {
      final res = await _db.rpc(
        'print_order_create',
        params: {
          'p_shop_id': shopId,
          'p_product_id': productId,
          'p_quantity': quantity,
          'p_delivery_address': address,
          'p_delivery_lat': lat,
          'p_delivery_lng': lng,
          'p_artwork_url': artworkUrl,
          'p_artwork_notes': artworkNotes,
          'p_specs': specs ?? const <String, dynamic>{},
          'p_payment_method': paymentMethod,
        },
      );
      final map = (res as Map?)?.cast<String, dynamic>();
      if (map == null) return const OrderResult(OrderOutcome.offline);
      if (map['ok'] != true) {
        return OrderResult(
          OrderOutcome.rejected,
          reason: map['error'] as String?,
        );
      }
      return OrderResult(
        OrderOutcome.created,
        orderId: map['order_id'] as String?,
        quote: PrintQuote.fromJson(map),
      );
    } catch (_) {
      return const OrderResult(OrderOutcome.offline);
    }
  }

  @override
  Future<bool> attachPayment(String orderId, String paymentRef) async {
    try {
      final res = await _db.rpc(
        'print_order_attach_payment',
        params: {'p_order_id': orderId, 'p_payment_ref': paymentRef},
      );
      return ((res as Map?)?['ok'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// أقرب مطبعة **لها موقع** لنقطة التوصيل.
///
/// مطبعة بلا إحداثيات لا تدخل الحساب بدل أن تُعامَل كأنها في الصفر —
/// نقطةٌ في خليج غينيا تجعلها «الأقرب» لكل طلب في الجزيرة العربية.
ShopRow? nearestShopRow(List<ShopRow> shops, double lat, double lng) {
  ShopRow? best;
  var bestKm = double.infinity;
  for (final s in shops) {
    if (!s.hasLocation) continue;
    // نفس هافرساين الذي يوجّه القائمة المحلية — حسابٌ واحد لا اثنان،
    // وإلا اختلف «الأقرب» بين المسارين على المسافات المتقاربة.
    final km = distanceKm(lat, lng, s.lat!, s.lng!);
    if (km < bestKm) {
      bestKm = km;
      best = s;
    }
  }
  return best;
}
