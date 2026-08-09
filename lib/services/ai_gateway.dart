import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ad_brief.dart';
import '../models/generation.dart';

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
  }) : _client = client ?? http.Client();

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
    final uri = Uri.parse('$baseUrl/api/generate/preview');

    late http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'productName': brief.productName,
              if (brief.productDescription != null &&
                  brief.productDescription!.trim().isNotEmpty)
                'productDescription': brief.productDescription,
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
