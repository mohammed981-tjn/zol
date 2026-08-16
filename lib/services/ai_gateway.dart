import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../config/app_config.dart';
import '../models/ad_brief.dart';
import '../models/generation.dart';
import '../models/seasonal_theme.dart';
import 'image_store.dart';

/// لون العلامة كما يُرسل للخادم في `primary` — لون زرّ الدعوة وميزان
/// الانسجام عند الناقد البصري.
///
/// لون فاتح جدًّا يُظلم إلى نفس الدرجة اللونية: نص الزر يُرسم بلون
/// [accentFromBrand] الفاتح، وفاتح على فاتح لا يُقرأ — أما داكن من عائلة
/// العلامة نفسها فيبقى هويةً وتُقرأ حروفه.
String primaryFromBrand(int rgb) {
  final hsl = _rgbToHsl(rgb);
  if (hsl.l <= 0.55) {
    return '#${(rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
  return _hslToHex(hsl.h, hsl.s, 0.32);
}

/// مرافق فاتح للون العلامة — حروف العنوان تُرسم فوق تظليل أسود في أعلى
/// الصورة، فتحتاج لونًا فاتحًا من عائلة العلامة نفسها لا ذهبيًا عامًّا.
///
/// نحفظ درجة اللون ونرفع الإضاءة إلى ٠٫٨ ونكبح التشبّع كي لا يصرخ اللون
/// فوق الصورة الفوتوغرافية.
String accentFromBrand(int rgb) {
  final hsl = _rgbToHsl(rgb);
  return _hslToHex(hsl.h, math.min(hsl.s, 0.60), 0.80);
}

({double h, double s, double l}) _rgbToHsl(int rgb) {
  final r = ((rgb >> 16) & 0xFF) / 255.0;
  final g = ((rgb >> 8) & 0xFF) / 255.0;
  final b = (rgb & 0xFF) / 255.0;
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final l = (maxC + minC) / 2;
  final d = maxC - minC;
  if (d == 0) return (h: 0, s: 0, l: l);
  final s = d / (1 - (2 * l - 1).abs());
  double h;
  if (maxC == r) {
    h = 60 * (((g - b) / d) % 6);
  } else if (maxC == g) {
    h = 60 * ((b - r) / d + 2);
  } else {
    h = 60 * ((r - g) / d + 4);
  }
  if (h < 0) h += 360;
  return (h: h, s: s, l: l);
}

String _hslToHex(double h, double s, double l) {
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  final (r, g, b) = switch (h) {
    < 60 => (c, x, 0.0),
    < 120 => (x, c, 0.0),
    < 180 => (0.0, c, x),
    < 240 => (0.0, x, c),
    < 300 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int ch(double v) => ((v + m) * 255).round().clamp(0, 255);
  final val = (ch(r) << 16) | (ch(g) << 8) | ch(b);
  return '#${val.toRadixString(16).padLeft(6, '0')}';
}

/// خطأ يحمل رسالة عربية جاهزة للعرض على المستخدم.
class GatewayException implements Exception {
  GatewayException(this.message, {this.isQuota = false, this.retryable = false});

  final String message;

  /// تجاوز الحصة — تُعالج في الواجهة بعرض مختلف عن الأخطاء العامة.
  final bool isQuota;

  /// خطأ مؤقت يستحق إعادة محاولة.
  final bool retryable;

  @override
  String toString() => message;
}

/// بوابة التطبيق إلى المنسّق.
///
/// التطبيق لا يعرف أي مزوّد ذكاء اصطناعي ولا يحمل أي مفتاح — المفاتيح كلها
/// في بيئة الخادم. هذا شرط أمني لا اختياري: مفتاح داخل التطبيق قابل
/// للاستخراج، وفاتورته على صاحب المشروع.
class AiGateway {
  AiGateway({
    required this.baseUrl,
    http.Client? client,
    this.accountId = 'demo',
    this.plan = 'free',
    // توليد ثلاث صور بالتوازي يضاعف الزمن؛ ٩٠ ثانية كانت تكفي النص وحده.
    this.timeout = const Duration(seconds: 150),
    // الإعداد يُحقن ولا يُقرأ من الثوابت العامة داخل الدوال: ثابت
    // String.fromEnvironment لا يمكن ضبطه وقت الاختبار، فقراءته في العمق
    // تجعل المسار غير قابل للاختبار أصلاً.
    bool? useSupabase,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? merchantId,
  })  : _client = client ?? http.Client(),
        useSupabase = useSupabase ?? AppConfig.useSupabase,
        supabaseUrl = supabaseUrl ?? AppConfig.supabaseUrl,
        supabaseAnonKey = supabaseAnonKey ?? AppConfig.supabaseAnonKey,
        merchantId = merchantId ?? AppConfig.merchantId;

  /// هل يُستعمل عقل Supabase المنشور بدل منسّق Node المحلي؟
  final bool useSupabase;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String merchantId;

  /// معرّف التاجر: المحقون إن وُجد، وإلا صاحب الجلسة المسجَّلة.
  ///
  /// كان يُقرأ من ‎--dart-define‎ وحده — وهو إعداد وقت بناء لا يعرف من
  /// يستعمل التطبيق، فكان كل تاجر يُنسب إليه معرّف واحد أو لا يُنسب أصلًا.
  /// وبعد أن قامت المصادقة صار صاحب الجلسة هو التاجر: `merchants.id` يشير
  /// إلى `auth.users.id` فالمعرّفان واحد.
  String get resolvedMerchantId {
    if (merchantId.isNotEmpty) return merchantId;
    try {
      return supa.Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {
      // الحزمة غير مهيّأة (اختبارات، أو إقلاع فاشل) — لا معرّف، ولا رمي.
      return '';
    }
  }

  /// عنوان المنسّق. في التطوير المحلي: http://10.0.2.2:8899 لمحاكي أندرويد،
  /// أو http://localhost:8899 للويب وسطح المكتب.
  final String baseUrl;

  final String accountId;
  final String plan;
  final Duration timeout;
  final http.Client _client;

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'x-account-id': accountId,
        'x-account-plan': plan,
      };

  /// المعاينة الرخيصة: نص + صورة خلفية. لا فيديو — الفيديو خلف بوابة الدفع.
  Future<PreviewResult> generatePreview(
    AdBrief brief, {
    bool includeImage = true,
  }) async {
    if (useSupabase) return _previewViaSupabase(brief);

    final uri = Uri.parse('$baseUrl/api/generate/preview');

    late http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'productName': brief.productName,
              if (brief.description.trim().isNotEmpty)
                'productDescription': brief.description,
              'tone': brief.tone,
              'platform': brief.platform,
              'includeImage': includeImage,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw GatewayException(
        'استغرق التوليد وقتاً أطول من المعتاد. حاول مرة أخرى.',
        retryable: true,
      );
    } catch (_) {
      throw GatewayException(
        'تعذّر الوصول إلى الخدمة. تحقّق من اتصالك ثم أعد المحاولة.',
        retryable: true,
      );
    }

    return _parse(res);
  }

  /// المعاينة عبر دالة `ad-copy` في Supabase — العقل المنشور.
  ///
  /// نصّ فقط: الصورة تأتي من دالة `ad-image` المنفصلة، فلا تُطلب هنا.
  /// الصيغ تصل مرتّبة بدرجة الوكيل الناقد، ولكل واحدة درجتها وملاحظتها.
  Future<PreviewResult> _previewViaSupabase(AdBrief brief) async {
    // رسائل موجَّهة للتاجر لا للمطوِّر: من يقرأها على جهازه لا يملك إعادة
    // البناء بـ‎--dart-define‎ ولا يعنيه أن يعرف ما هي.
    if (supabaseUrl.isEmpty) {
      throw GatewayException(
        'تعذّر الوصول إلى الخادم. حدّث التطبيق إلى آخر إصدار.',
      );
    }
    final merchant = resolvedMerchantId;
    if (merchant.isEmpty) {
      throw GatewayException('سجّل الدخول أولًا حتى تُحفظ إعلاناتك باسمك.');
    }

    // ad-magic لا ad-copy: السلسلة الكاملة في نداء واحد — كاتب ← ناقد ←
    // ثلاث صور بالتوازي بحروف عربية مرسومة ومدقَّقة ← السجل. النصّ وحده
    // كان يترك التصميم كله على عاتق الجهاز.
    final uri = Uri.parse(
      '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}'
      '/functions/v1/ad-magic',
    );

    // وصف المنتج يُدمج في اسمه: دالة ad-copy تأخذ حقل منتج واحداً، وإسقاط
    // الوصف يفقد أدقّ ما يكتبه التاجر عن سلعته.
    final product = brief.description.trim().isEmpty
        ? brief.productName
        : '${brief.productName} — ${brief.description.trim()}';

    // هوية العلامة تسافر مع الطلب: لون التاجر الصريح يغلب المستخرَج من
    // صورة المنتج، وكلاهما خير من افتراضيات خادمٍ يجهل صاحب الإعلان.
    final brandRgb = brief.brandColor ?? brief.paletteColor;
    final brandName = brief.brandName?.trim() ?? '';

    // صورة المنتج الحقيقية تسافر أيضًا — فيظهر في الإعلان منتجُ التاجر
    // لا تخيّل النموذج عنه. تُضغط بنفس ضاغط المكتبة (≤١٠٠٠ بكسل، PNG
    // للقصاصة الشفافة). قصاصة فوتوغرافية مفصّلة قد تتجاوز حدَّ الإرسال
    // فكانت تُسقَط بصمت ويخرج الإعلان بلا منتج — الآن تُصغَّر تمريرةً
    // ثانية (٦٤٠ بكسل تكفي لثلث الإعلان الأوسط)، والإسقاط آخر الدواء:
    // طلب يموت بمهلة الشبكة على اتصالٍ ضعيف أسوأ من صورة أصغر.
    const maxProductB64 = 2000000;
    String? productB64;
    final productBytes = brief.imageBytes;
    if (productBytes != null && productBytes.isNotEmpty) {
      try {
        var compact = await ImageStore.compressForStorage(productBytes);
        var encoded = base64Encode(compact);
        if (encoded.length > maxProductB64) {
          compact = await ImageStore.compressForStorage(compact, maxWidth: 640);
          encoded = base64Encode(compact);
        }
        if (encoded.length <= maxProductB64) productB64 = encoded;
      } catch (_) {
        // الصورة إثراء لا شرط — تعذّر ضغطها لا يمنع التوليد.
      }
    }

    late http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              if (supabaseAnonKey.isNotEmpty) ...{
                'apikey': supabaseAnonKey,
                'authorization': 'Bearer $supabaseAnonKey',
              },
            },
            body: jsonEncode({
              'merchant_id': merchant,
              'product': product,
              'platform': brief.platform,
              'tone': brief.tone,
              if (brief.season != null) 'season': brief.season!.label,
              if (brandName.isNotEmpty) 'brand_name': brandName,
              if (brandRgb != null) ...{
                'primary': primaryFromBrand(brandRgb),
                'accent': accentFromBrand(brandRgb),
              },
              'product_b64': ?productB64,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw GatewayException(
        'استغرق التوليد وقتاً أطول من المعتاد. حاول مرة أخرى.',
        retryable: true,
      );
    } catch (_) {
      throw GatewayException(
        'تعذّر الوصول إلى الخدمة. تحقّق من اتصالك ثم أعد المحاولة.',
        retryable: true,
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw GatewayException('وصل رد غير مفهوم من الخدمة.');
    }

    if (res.statusCode != 200 || json['ok'] != true) {
      throw GatewayException(
        _arabicError(json),
        retryable: res.statusCode >= 500,
      );
    }

    final result = PreviewResult.fromAdCopyJson(json);
    if (result.variants.isEmpty) {
      throw GatewayException('لم تُنتج الخدمة أي صيغة. حاول بوصف أوضح للمنتج.');
    }
    return result;
  }

  /// رسائل دالة ad-copy رموز تقنية؛ نترجم المعروف منها ونمرّر الباقي.
  String _arabicError(Map<String, dynamic> json) {
    final code = (json['error'] ?? json['step'] ?? '').toString();
    if (code.startsWith('no_api_key')) {
      return 'مفتاح المزوّد غير مضبوط في بيئة الدالة.';
    }
    if (code.startsWith('openrouter_all_failed')) {
      return 'كل النماذج المجانية مزدحمة الآن. أعد المحاولة بعد قليل.';
    }
    if (code.contains('_429') || code.contains('quota')) {
      return 'تجاوزت حصة المزوّد. أعد المحاولة لاحقاً.';
    }
    if (code == 'writer') return 'لم يُنتج النموذج صيغاً صالحة. أعد المحاولة.';
    return code.isEmpty ? 'حدث خطأ غير متوقع.' : code;
  }

  Future<QuotaStatus> fetchUsage() async {
    final res = await _client
        .get(Uri.parse('$baseUrl/api/usage'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw GatewayException('تعذّر قراءة حالة الاستخدام.');
    }
    return QuotaStatus.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  PreviewResult _parse(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw GatewayException('وصل رد غير مفهوم من الخدمة.');
    }

    if (res.statusCode == 200) {
      final result = PreviewResult.fromJson(json);
      if (result.variants.isEmpty) {
        throw GatewayException('لم تُنتج الخدمة أي صيغة. حاول بوصف أوضح للمنتج.');
      }
      return result;
    }

    final message = (json['message'] as String?) ?? 'حدث خطأ غير متوقع.';

    if (res.statusCode == 429) {
      throw GatewayException(message, isQuota: true);
    }
    if (res.statusCode == 503) {
      throw GatewayException(
        'الخدمة مشغولة حالياً. أعد المحاولة بعد لحظات.',
        retryable: true,
      );
    }
    throw GatewayException(message);
  }

  void dispose() => _client.close();
}
