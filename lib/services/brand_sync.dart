/// مزامنة هوية العلامة بين أجهزة التاجر.
///
/// اللون والشعار والخط تُحفظ على الجهاز أولًا ودائمًا — التطبيق يعمل بلا
/// إنترنت، والسحابة **طبقة مزامنة لا شرط تشغيل**. فكل دالة هنا تفشل
/// بصمت: لا شبكة، لا جلسة، خادم متعثّر — كلها تعني «لا مزامنة الآن»، لا
/// «توقّف عن العمل».
///
/// حسم التعارض بالأحدث كتابةً، والتاريخ من الخادم لا من الجهاز: ساعة
/// الهاتف قد تكون مغلوطة فيغلب جهازٌ قديمٌ جديدًا.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// لقطة هوية العلامة كما تُخزَّن سحابيًا.
class BrandIdentity {
  const BrandIdentity({
    this.colorValue,
    this.fontName,
    this.logoBytes,
    this.updatedAt,
  });

  final int? colorValue;
  final String? fontName;
  final Uint8List? logoBytes;
  final DateTime? updatedAt;

  bool get isEmpty =>
      colorValue == null && fontName == null && logoBytes == null;

  /// `#RRGGBB` ← عدد فلاتر معتم. ألوان العلامة كلها معتمة، فإسقاط قناة
  /// الشفافية بلا خسارة، والنصّ الست عشري يقرؤه أي مستهلك آخر للجدول.
  static String colorToHex(int value) =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static int? _colorFromHex(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceFirst('#', '').trim();
    if (clean.length != 6) return null;
    final rgb = int.tryParse(clean, radix: 16);
    return rgb == null ? null : 0xFF000000 | rgb;
  }

  static BrandIdentity? fromJson(Map<String, dynamic> j) {
    Uint8List? logo;
    final raw = j['logo_base64'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        logo = base64Decode(raw);
      } catch (_) {
        // شعار تالف في السحابة لا يمنع استرجاع اللون والخط.
        logo = null;
      }
    }
    return BrandIdentity(
      colorValue: _colorFromHex(j['primary_color'] as String?),
      fontName: j['font_name'] as String?,
      logoBytes: logo,
      updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? ''),
    );
  }
}

class BrandSync {
  BrandSync({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  /// حدّ الشعار — يطابق قيد `brand_logo_size` في القاعدة.
  ///
  /// الرفض هنا قبل الإرسال يوفّر رحلة تنتهي بخطأ قاعدة غامض، ويترك الشعار
  /// سليمًا على الجهاز بدل أن يُفقد في محاولة رفع فاشلة.
  static const maxLogoBase64 = 700000;

  SupabaseClient? get _clientOrNull {
    if (_injected != null) return _injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _merchantId => _clientOrNull?.auth.currentUser?.id;

  bool get isReady => _clientOrNull != null && _merchantId != null;

  /// يجلب الهوية المحفوظة، أو `null` إن لم توجد أو تعذّر الوصول.
  Future<BrandIdentity?> fetch() async {
    final db = _clientOrNull;
    final id = _merchantId;
    if (db == null || id == null) return null;
    try {
      final row = await db
          .from('brand_identities')
          .select('primary_color,font_name,logo_base64,updated_at')
          .eq('merchant_id', id)
          .maybeSingle();
      if (row == null) return null;
      return BrandIdentity.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// يرفع الهوية الحالية. يعيد `true` إن وصلت.
  ///
  /// `updated_at` لا يُرسَل: مُشغِّل في القاعدة يضبطه، فلا يكتب جهازٌ
  /// تاريخَه بنفسه ويغلب غيره بساعة مغلوطة.
  Future<bool> push({
    int? colorValue,
    String? fontName,
    Uint8List? logoBytes,
  }) async {
    final db = _clientOrNull;
    final id = _merchantId;
    if (db == null || id == null) return false;

    String? logo;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      final encoded = base64Encode(logoBytes);
      if (encoded.length > maxLogoBase64) return false;
      logo = encoded;
    }

    try {
      await db.from('brand_identities').upsert(
        {
          'merchant_id': id,
          'primary_color':
              colorValue == null ? null : BrandIdentity.colorToHex(colorValue),
          'font_name': fontName,
          'logo_base64': logo,
        },
        // المفتاح الأساسي هو id لا merchant_id، فالتعارض يُحسم على القيد
        // الفريد صراحةً — وإلا أدرج upsert صفًّا جديدًا لكل حفظ.
        onConflict: 'merchant_id',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
