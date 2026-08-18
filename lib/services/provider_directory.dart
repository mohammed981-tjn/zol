import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ad_service.dart';

/// دليل المزوّدين — من ملفّ في التطبيق إلى جدول على الخادم.
///
/// الدليل كان تسعة مزوّدين مكتوبين في `ad_service.dart`: كل مزوّد جديد
/// يحتاج بناءً ونشرًا وتحديثًا على كل جهاز، والسوق مهما كبر يبقى قائمةً
/// نكتبها نحن.
///
/// وهذه الطبقة تقرأ من الخادم **وتسقط إلى المحلّي** عند تعذّره. السقوط
/// ليس تهاونًا: السوق تبويب رئيسي، وشبكةُ تاجرٍ في محلّه قد تنقطع، وشاشةٌ
/// فارغة بها رسالة خطأ أسوأ من قائمةٍ أقدم بقليل. والمزوّدون المحلّيون
/// حقيقيون على كل حال — شبكة المطابع التي نوجّه إليها الطلبات فعلًا.
class ProviderDirectory {
  const ProviderDirectory._();

  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // التطبيق يعمل في الاختبارات وفي وضع بلا خادم بلا تهيئة.
      return null;
    }
  }

  /// المزوّدون المعتمَدون. يبدأ بالمحلّيين ثم يضيف من الخادم.
  ///
  /// الدمج لا الاستبدال: شبكة المطابع مصدرها الكتالوج المحلّي وأسعارها
  /// تُحسب منه، فلا تُنسخ إلى الخادم لئلّا يصير للسعر مصدرا حقيقة.
  static Future<List<ServiceProvider>> approved() async {
    final db = _db;
    if (db == null) return serviceProviders;
    try {
      final rows = await db
          .from('service_providers')
          .select(
            'id,name,kind,city,tagline,price_from,responds_in_hours,'
            'works,verified',
          )
          .eq('status', 'approved');
      final remote = rows.map(_fromRow).whereType<ServiceProvider>().toList();
      return [...serviceProviders, ...remote];
    } catch (_) {
      return serviceProviders;
    }
  }

  /// إدراج التاجر الحالي (في كل حالاته) — ليعرف أنه قيد المراجعة أو
  /// سبب رفضه. `null` يعني لم يسجّل بعد.
  static Future<ProviderListing?> mine() async {
    final db = _db;
    final uid = db?.auth.currentUser?.id;
    if (db == null || uid == null) return null;
    try {
      final rows = await db
          .from('service_providers')
          .select()
          .eq('owner_id', uid)
          .limit(1);
      if (rows.isEmpty) return null;
      return ProviderListing.fromRow(rows.first);
    } catch (_) {
      return null;
    }
  }

  /// يسجّل إدراجًا جديدًا. الحالة والتوثيق يفرضهما الخادم لا نحن —
  /// إرسالهما من هنا لا يُصدَّق، والحارس في القاعدة يعيدهما.
  static Future<String?> submit({
    required ServiceKind kind,
    required String name,
    required String city,
    required String tagline,
    required int priceFrom,
    int? respondsInHours,
    List<String> works = const [],
  }) async {
    final db = _db;
    final uid = db?.auth.currentUser?.id;
    if (db == null || uid == null) return 'not_signed_in';
    try {
      await db.from('service_providers').insert({
        'owner_id': uid,
        'kind': kind.name,
        'name': name.trim(),
        'city': city.trim(),
        'tagline': tagline.trim(),
        'price_from': priceFrom,
        'responds_in_hours': respondsInHours,
        'works': works.where((w) => w.trim().isNotEmpty).toList(),
      });
      return null;
    } on PostgrestException catch (e) {
      // القيد الفريد على (المالك، الصنف) هو أشيع سبب رفض، ورسالة
      // Postgres الخام لا تفيد التاجر في شيء.
      if (e.code == '23505') return 'duplicate';
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}

/// إدراج المزوّد كما يراه صاحبه — بحالته وسبب مراجعته.
class ProviderListing {
  const ProviderListing({
    required this.id,
    required this.name,
    required this.kind,
    required this.status,
    required this.verified,
    this.reviewNote,
  });

  final String id;
  final String name;
  final ServiceKind kind;
  final ProviderStatus status;
  final bool verified;
  final String? reviewNote;

  factory ProviderListing.fromRow(Map<String, dynamic> row) => ProviderListing(
    id: row['id'] as String? ?? '',
    name: row['name'] as String? ?? '',
    kind: _kindFrom(row['kind'] as String?) ?? ServiceKind.printing,
    status: switch (row['status'] as String?) {
      'approved' => ProviderStatus.approved,
      'rejected' => ProviderStatus.rejected,
      _ => ProviderStatus.pending,
    },
    verified: row['verified'] as bool? ?? false,
    reviewNote: row['review_note'] as String?,
  );
}

enum ProviderStatus { pending, approved, rejected }

extension ProviderStatusInfo on ProviderStatus {
  String get label => switch (this) {
    ProviderStatus.pending => 'قيد المراجعة',
    ProviderStatus.approved => 'معتمَد ويظهر في السوق',
    ProviderStatus.rejected => 'مرفوض',
  };
}

ServiceKind? _kindFrom(String? name) {
  if (name == null) return null;
  for (final k in ServiceKind.values) {
    if (k.name == name) return k;
  }
  return null;
}

/// يحوّل صفًّا من الخادم إلى مزوّد للعرض.
///
/// التقييم غائب عمدًا: لا تقييمات حتى يوجد طلب حقيقي يُقيَّم. المزوّد
/// الجديد يُعرض بلا نجوم — وذلك أصدق من نجومٍ نمنحها ابتداءً.
ServiceProvider? _fromRow(Map<String, dynamic> row) {
  final kind = _kindFrom(row['kind'] as String?);
  final id = row['id'] as String?;
  final name = row['name'] as String?;
  if (kind == null || id == null || name == null) return null;
  return ServiceProvider(
    id: id,
    name: name,
    kind: kind,
    city: row['city'] as String? ?? '',
    tagline: row['tagline'] as String? ?? '',
    priceFrom: (row['price_from'] as num?)?.toInt() ?? 0,
    rating: 0,
    reviews: 0,
    works: ((row['works'] as List?) ?? const [])
        .map((w) => w.toString())
        .toList(),
    verified: row['verified'] as bool? ?? false,
    respondsInHours: (row['responds_in_hours'] as num?)?.toInt(),
  );
}
