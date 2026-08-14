import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ad_brief.dart';
import '../models/generation.dart';
import '../models/seasonal_theme.dart';

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
    this.timeout = const Duration(seconds: 90),
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
    if (supabaseUrl.isEmpty) {
      throw GatewayException(
        'عنوان Supabase غير مضبوط. مرّره وقت البناء بـ '
        '--dart-define=SUPABASE_URL=...',
      );
    }
    if (merchantId.isEmpty) {
      throw GatewayException(
        'معرّف التاجر غير مضبوط. مرّره وقت البناء بـ '
        '--dart-define=MERCHANT_ID=... حتى يُنسب التوليد لصاحبه.',
      );
    }

    final uri = Uri.parse(
      '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}'
      '/functions/v1/ad-copy',
    );

    // وصف المنتج يُدمج في اسمه: دالة ad-copy تأخذ حقل منتج واحداً، وإسقاط
    // الوصف يفقد أدقّ ما يكتبه التاجر عن سلعته.
    final product = brief.description.trim().isEmpty
        ? brief.productName
        : '${brief.productName} — ${brief.description.trim()}';

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
              'merchant_id': merchantId,
              'product': product,
              'platform': brief.platform,
              'tone': brief.tone,
              if (brief.season != null) 'season': brief.season!.label,
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
