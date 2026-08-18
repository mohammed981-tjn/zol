import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../config/app_config.dart';
import '../models/ad_format.dart';
import '../models/design_spec.dart';
import 'spec_doctor.dart';

/// أمنية التاجر — ما يكتبه بحرّيته في شاشة السحر، ويُنفَّذ تخطيطًا.
///
/// هذا هو الفرق بين «املأ الحقول» و«قل ما تريد». الحقول تحصر التاجر فيما
/// توقّعناه، والنصّ الحرّ يفتح ما لم نتوقّعه — والنموذج يترجمه إلى
/// [DesignSpec] لا إلى نصّ إعلاني، فيتغيّر **التكوين** لا الكلمات وحدها.
class DesignWish {
  const DesignWish({
    required this.text,
    required this.format,
    this.product,
    this.brandName,
    this.tone,
    this.hasImage = false,
    this.count = 2,
  });

  /// ما كتبه التاجر حرفيًّا. لا نُعيد صياغته ولا نُلحق به قوالبنا: كلّ
  /// تهذيب هنا يسرق منه ما أراد قوله.
  final String text;

  final AdFormat format;
  final String? product;
  final String? brandName;
  final String? tone;
  final bool hasImage;

  /// عدد التخطيطات المطلوبة. اثنان افتراضًا: واحد لا يترك خيارًا،
  /// وأربعة تُضاعف زمن الانتظار على جوال في شبكة ضعيفة.
  final int count;

  Map<String, dynamic> toJson() => {
    'wish': text,
    'format': format.label,
    'aspect': format.aspect,
    if (product != null && product!.trim().isNotEmpty) 'product': product,
    if (brandName != null && brandName!.trim().isNotEmpty)
      'brand_name': brandName,
    if (tone != null && tone!.trim().isNotEmpty) 'tone': tone,
    'has_image': hasImage,
    'count': count.clamp(1, 4),
  };
}

/// تخطيط واحد كما وصل من النموذج، وبعد أن مرّ عليه الطبيب.
class WishDesign {
  const WishDesign({required this.report, required this.attempt});

  final SpecReport report;

  /// المحاولة التي أنتجته (١ أو ٢). يُفيد في التشخيص: هل يُصيب النموذج
  /// من أوّل مرّة أم يحتاج إعادة؟
  final int attempt;

  DesignSpec get spec => report.spec;
  bool get usable => report.usable;
}

class WishResult {
  const WishResult({
    required this.designs,
    required this.model,
    required this.ms,
    required this.attempts,
  });

  /// مرتّبة: الصالح أوّلًا، ثم الأقلّ عللًا.
  final List<WishDesign> designs;
  final String model;
  final int ms;
  final int attempts;

  bool get hasUsable => designs.any((d) => d.usable);
}

class DesignWishException implements Exception {
  DesignWishException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}

/// بوابة التطبيق إلى دالة `ad-design`.
///
/// الفصل عن `AiGateway` مقصود: تلك تُخرج **نصًّا** (عنوان ووصف
/// وهاشتاقات) وهذه تُخرج **تخطيطًا**. خلطهما في صنف واحد يعني ردًّا
/// واحدًا يحمل شكلين، وأوّل تغيير في أحدهما يكسر الآخر.
class DesignWishService {
  DesignWishService({
    http.Client? client,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? merchantId,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client(),
       supabaseUrl = supabaseUrl ?? AppConfig.supabaseUrl,
       supabaseAnonKey = supabaseAnonKey ?? AppConfig.supabaseAnonKey,
       _merchantId = merchantId ?? AppConfig.merchantId;

  final http.Client _client;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String _merchantId;
  final Duration timeout;

  String get resolvedMerchantId {
    if (_merchantId.isNotEmpty) return _merchantId;
    try {
      return supa.Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {
      return '';
    }
  }

  void dispose() => _client.close();

  /// ينفّذ الأمنية ويعيد تخطيطات **مفحوصة**.
  ///
  /// إعادة المحاولة مرّة واحدة حين لا يصلح أيّ تخطيط: النموذج يُخطئ في
  /// الإحداثيات أحيانًا فيخرج عنوانٌ فوق عنوان لا فراغ لإنزاله. ومرّة
  /// واحدة لا أكثر — التاجر ينتظر أمام شاشة، ومحاولةٌ ثالثة تعني ثلاثين
  /// ثانية صمتٍ إضافي مقابل احتمال ضئيل.
  ///
  /// وحين تفشل المحاولتان **لا نرمي**: نعيد أقلّ التخطيطات عللًا مع
  /// تقريره. تصميمٌ فيه ملاحظة يراها التاجر ويصلحها خيرٌ من شاشة خطأ
  /// تُخفي عنه أن النموذج أجاب أصلًا.
  Future<WishResult> design(
    DesignWish wish, {
    required Color brandColor,
    bool hasLogo = false,
  }) async {
    final text = wish.text.trim();
    if (text.isEmpty) {
      throw DesignWishException('اكتب ما تريد أوّلًا — سطر واحد يكفي.');
    }
    if (supabaseUrl.isEmpty) {
      throw DesignWishException(
        'تعذّر الوصول إلى الخادم. حدّث التطبيق إلى آخر إصدار.',
      );
    }

    final started = DateTime.now();
    var model = '';
    List<WishDesign> best = const [];

    for (var attempt = 1; attempt <= 2; attempt++) {
      final raw = await _call(wish, attempt: attempt);
      model = raw.model;

      final judged = [
        for (final j in raw.specs)
          WishDesign(
            report: SpecDoctor.review(
              // الصيغة تأتي من التاجر لا من النموذج: هو اختارها في
              // الشاشة، وما يقترحه النموذج في حقل `format` تخمينٌ قد
              // يخالف اللوحة التي سيُرسم عليها فعلًا.
              _withFormat(DesignSpec.fromJson(j), wish.format),
              brandColor: brandColor,
              hasLogo: hasLogo,
            ),
            attempt: attempt,
          ),
      ];

      judged.sort((a, b) {
        if (a.usable != b.usable) return a.usable ? -1 : 1;
        return a.report.blocking.length.compareTo(b.report.blocking.length);
      });

      if (best.isEmpty ||
          (judged.isNotEmpty &&
              judged.first.report.blocking.length <
                  best.first.report.blocking.length)) {
        best = judged;
      }
      if (best.isNotEmpty && best.first.usable) {
        return WishResult(
          designs: best,
          model: model,
          ms: DateTime.now().difference(started).inMilliseconds,
          attempts: attempt,
        );
      }
    }

    if (best.isEmpty) {
      throw DesignWishException(
        'لم يُخرج الذكاء تخطيطًا مفهومًا. جرّب صياغة أوضح.',
        retryable: true,
      );
    }
    return WishResult(
      designs: best,
      model: model,
      ms: DateTime.now().difference(started).inMilliseconds,
      attempts: 2,
    );
  }

  DesignSpec _withFormat(DesignSpec s, AdFormat format) => DesignSpec(
    format: format,
    backdrop: s.backdrop,
    elements: s.elements,
    variant: s.variant,
    note: s.note,
  );

  Future<({List<Map<String, dynamic>> specs, String model})> _call(
    DesignWish wish, {
    required int attempt,
  }) async {
    final uri = Uri.parse(
      '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/functions/v1/ad-design',
    );
    final merchant = resolvedMerchantId;

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
              ...wish.toJson(),
              if (merchant.isNotEmpty) 'merchant_id': merchant,
              // المحاولة الثانية تُشدَّد لا تُعاد كما هي: إعادةُ الطلب
              // نفسه على نموذج بنفس الحرارة تُرجّح مخرَجًا مشابهًا.
              if (attempt > 1)
                'wish':
                    '${wish.text.trim()}\n\n'
                    'المحاولة السابقة تداخلت عناصرها. باعد بين الكتل '
                    'باعدًا واضحًا، وابقِ كل عنصر بين ٠٫٠٨ و٠٫٩٢.',
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw DesignWishException(
        'استغرق التصميم وقتًا أطول من المعتاد. حاول مرة أخرى.',
        retryable: true,
      );
    } catch (_) {
      throw DesignWishException(
        'تعذّر الوصول إلى الخدمة. تحقّق من اتصالك ثم أعد المحاولة.',
        retryable: true,
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw DesignWishException('وصل ردّ غير مفهوم من الخدمة.');
    }

    if (res.statusCode != 200 || body['ok'] != true) {
      throw DesignWishException(
        _arabicError(body),
        retryable: res.statusCode >= 500,
      );
    }

    final specs = ((body['designs'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList(growable: false);

    return (specs: specs, model: body['model'] as String? ?? '');
  }

  static String _arabicError(Map<String, dynamic> body) {
    final code = (body['error'] ?? body['step'] ?? '').toString();
    if (code.contains('no_api_key')) {
      return 'مفتاح الذكاء غير مهيّأ على الخادم.';
    }
    if (code.contains('wish_or_product_required')) {
      return 'اكتب ما تريد أوّلًا — سطر واحد يكفي.';
    }
    if (code.contains('429') || code.contains('quota')) {
      return 'الخدمة مزدحمة الآن. أعد المحاولة بعد قليل.';
    }
    if (code.contains('prompt_missing')) {
      return 'إعداد المصمّم ناقص على الخادم.';
    }
    return 'تعذّر التصميم. حاول مرة أخرى.';
  }
}
