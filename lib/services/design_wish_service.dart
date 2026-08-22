import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../config/app_config.dart';
import '../models/ad_format.dart';
import '../models/design_spec.dart';
import 'design_critic.dart';
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
    this.base,
    this.mood,
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

  /// تخطيط قائم يُراد **تعديله** لا استبداله.
  ///
  /// أرخص من إعادة التوليد، وأهمّ من ذلك: يحفظ ما أعجب التاجر. من رضي
  /// عن تكوينه وأزعجه حجم عنوان لا يجوز أن نُجبره على مقامرة بتكوين
  /// جديد كاملًا.
  final DesignSpec? base;

  /// المزاج اللونيّ الذي اختاره التاجر، أو `null` أي الاشتقاق من لون
  /// علامته.
  ///
  /// يُرسل إلى النموذج **ويُفرض على ما يعود**: اختيارٌ صريح اتّخذه
  /// التاجر بيده لا يجوز أن يُلغيه تخمينُ نموذج. والنموذج يبقى حرًّا
  /// حين لا يختار التاجر شيئًا.
  final int? mood;

  /// النصّ كما يصل النموذج.
  ///
  /// المواصفة الأساس تُدمج في نصّ الأمنية لا في حقل مستقلّ: الدالّة
  /// المنشورة تمرّر `wish` حرفيًّا إلى النموذج، فالتعديل يعمل اليوم بلا
  /// نشرٍ جديد. ويُرسل `base` أيضًا كحقل ليستعمله إصدار لاحق من الدالّة
  /// استعمالًا مقيَّدًا بمخطط بدل الدمج في النصّ.
  String get promptText {
    final b = base;
    if (b == null) return text;
    return '${text.trim()}\n\n'
        'هذا تخطيط قائم. عدّله بما طُلب أعلاه فقط، وأبقِ ما لم يُذكر كما '
        'هو، وأعِد إخراجه كاملًا بنفس الشكل:\n'
        '${jsonEncode(b.toJson())}';
  }

  Map<String, dynamic> toJson() => {
    'wish': promptText,
    if (base != null) 'base': base!.toJson(),
    'format': format.label,
    'aspect': format.aspect,
    if (product != null && product!.trim().isNotEmpty) 'product': product,
    if (brandName != null && brandName!.trim().isNotEmpty)
      'brand_name': brandName,
    if (tone != null && tone!.trim().isNotEmpty) 'tone': tone,
    'has_image': hasImage,
    'count': count.clamp(1, 4),
    if (mood != null) 'mood': mood,
  };
}

/// تخطيط واحد كما وصل من النموذج، وبعد أن مرّ عليه الطبيب **والناقد**.
class WishDesign {
  const WishDesign({
    required this.report,
    required this.score,
    required this.attempt,
  });

  final SpecReport report;

  /// درجة الناقد — تسلسل واصطفاف وتوازن وفراغ وإيقاع وبؤرة.
  ///
  /// كان هذا المسار يفرز بـ`usable` ثم عدد العلل الحاجبة وحدهما، فيختار
  /// من أربعة تخطيطات **أقلَّها عيوبًا** لا **أجودها**. والفرق ليس
  /// لفظيًّا: انعدامُ العلل شرطُ عرضٍ لا دليلُ جودة — تخطيطان بلا علّة
  /// واحدة يتساويان في ذلك الفرز مهما تباعدت درجتاهما، فيُحسم المعروض
  /// بترتيب النموذج لا بقياس.
  ///
  /// والناقد كان مبنيًّا وموزونًا ويعمل — لكن في `LocalDesigner` وحده.
  /// أي أن مسار الجهاز يقيس ألفًا ومئتَي مرشَّح ويختار أعلاها، ومسار
  /// السحابة — وهو ما يراه التاجر حين يكتب أمنيته — يُحكَّم بمعيار أضعف.
  final DesignScore score;

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
  /// ترتيب المرشّحين: الصالح أوّلًا، ثم **الأجود درجةً**، ثم الأقلّ عللًا.
  ///
  /// والصلاحية تسبق الدرجة ولا تُوزن معها: تخطيطٌ لا يُقرأ عنوانه ليس
  /// «أدنى جودة» بل غير صالح للعرض، فلا يرفعه اصطفافٌ جميل فوق صالحٍ
  /// أقلّ أناقة.
  static int _rank(WishDesign a, WishDesign b) {
    if (a.usable != b.usable) return a.usable ? -1 : 1;
    final byScore = b.score.total.compareTo(a.score.total);
    if (byScore != 0) return byScore;
    return a.report.blocking.length.compareTo(b.report.blocking.length);
  }

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
      final ({List<Map<String, dynamic>> specs, String model}) raw;
      try {
        raw = await _call(wish, attempt: attempt);
      } on DesignWishException {
        // فشل المحاولة الثانية لا يمحو حصاد الأولى. كان الاستثناء يصعد
        // فيضيع تخطيطٌ صالح للعرض بعلّة واحدة، ويرى التاجر رسالة عطل
        // بينما التصميم كان في اليد.
        if (attempt > 1 && best.isNotEmpty) break;
        rethrow;
      }
      model = raw.model;

      final judged = [
        for (final j in raw.specs)
          () {
            final spec = _withChoices(
              DesignSpec.fromJson(j),
              wish.format,
              wish.mood,
            );
            return WishDesign(
              report: SpecDoctor.review(
                spec,
                brandColor: brandColor,
                hasLogo: hasLogo,
              ),
              score: DesignCritic.score(
                spec,
                brandColor: brandColor,
                hasLogo: hasLogo,
              ),
              attempt: attempt,
            );
          }(),
      ];

      judged.sort(_rank);

      // والمقارنة بين المحاولتين بالمعيار نفسه الذي رُتّبت به كلٌّ منهما.
      // كانت تقارن عدد العلل وحده، فمحاولةٌ ثانية بلا علّة تُزيح أولى
      // بلا علّة وإن كانت أدنى درجةً — أي أن إعادة الطلب كانت تُقامر
      // بما في اليد.
      if (best.isEmpty ||
          (judged.isNotEmpty && _rank(judged.first, best.first) < 0)) {
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

  /// يفرض ما اختاره التاجر على ما أعاده النموذج.
  ///
  /// الصيغة تأتي منه لا من النموذج: هو اختارها في الشاشة، وما يقترحه
  /// النموذج في `format` تخمينٌ قد يخالف اللوحة التي سيُرسم عليها فعلًا.
  ///
  /// والمزاج مثلها حين يُختار: تاجرٌ ضغط «بحريّ بارد» ثم رأى تصميمًا
  /// ترابيًّا يظنّ الزرّ معطّلًا. أمّا حين لا يختار ([wishMood] فارغ)
  /// فيبقى ما اقترحه النموذج — أو `null` فيُشتقّ من لون العلامة.
  DesignSpec _withChoices(DesignSpec s, AdFormat format, int? wishMood) =>
      DesignSpec(
        format: format,
        backdrop: s.backdrop,
        elements: s.elements,
        variant: s.variant,
        pairing: s.pairing,
        mood: wishMood ?? s.mood,
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
                    '${wish.promptText}\n\n'
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
