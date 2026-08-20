import '../models/ad_format.dart';

/// نوع العرض الذي طلبه التاجر.
enum WishOffer {
  discount,
  opening,
  newItem,
  hiring,
  delivery,
  season,

  /// لم يُفهم نوعٌ بعينه — إعلان تعريفي عامّ.
  general,
}

/// ما فهمه الجهاز من أمنية التاجر.
class WishIntent {
  const WishIntent({
    required this.offer,
    required this.raw,
    this.discountPercent,
    this.format,
    this.tone,
    this.wantsLight,
    this.urgent = false,
    this.subject,
  });

  final WishOffer offer;

  /// النصّ كما كتبه — يبقى مرجعًا لا يُستبدل بفهمنا له.
  final String raw;

  /// نسبة الخصم إن ذُكرت. تُستخرج بالأرقام العربية والهندية معًا.
  final int? discountPercent;

  /// صيغة اللوحة إن سمّاها («رول أب»، «كرت»…).
  final AdFormat? format;

  /// نبرة مفهومة من كلمات مثل «فخم» و«مرح».
  final String? tone;

  /// هل طلب خلفية فاتحة أو داكنة صراحةً؟ `null` يعني لم يذكر.
  final bool? wantsLight;

  /// إلحاح: «اليوم»، «آخر يوم»، «لفترة محدودة».
  final bool urgent;

  /// صاحب الإعلان أو موضوعه كما ذكره التاجر: «مقهى مختص»، «عيادة أسنان».
  ///
  /// من غيره كان الإعلان يُبنى على المنتج المخزَّن في الموجز، فيكتب
  /// التاجر «كرت أعمال لعيادة أسنان» ويخرج له عنوانٌ عن القهوة — لأنه
  /// رفع صورة قهوة في جلسة سابقة. وأن يُتجاهل ما كتبه للتوّ أسوأ من
  /// ألّا نفهمه.
  final String? subject;

  bool get hasDiscount => (discountPercent ?? 0) > 0;
}

/// قارئ الأمنية على الجهاز — أوّل طبقة من الذكاء المحلّي.
///
/// الأمنية تُرسَل إلى النموذج في السحابة، وهذا حسن. لكن الاعتماد عليه
/// وحده يعني ثلاثة أشياء سيّئة: انتظارٌ ثماني ثوانٍ قبل أن يرى التاجر
/// شيئًا، وسقوطٌ تامّ حين تنقطع الشبكة أو تنفد الحصّة، وحصّةٌ تُنفَق على
/// طلبٍ كان يمكن فهمه هنا مجّانًا («خصم ٣٠٪» لا تحتاج نموذجًا لغويًّا).
///
/// وهذا القارئ لا يدّعي فهمًا لغويًّا عامًّا. يستخرج ما هو **قابل
/// للاستخراج يقينًا**: نوع العرض، ونسبة الخصم، والصيغة، والنبرة،
/// والإلحاح. وما لم يفهمه يبقى نصًّا خامًا يذهب إلى النموذج.
///
/// والتطبيع مقصود ومهمّ: التاجر يكتب «إفتتاح» و«افتتاح» و«اِفتتاح»،
/// و«٣٠٪» و«30%» و«30 بالمئة». ومطابقةٌ حرفية تفشل في أكثرها.
class WishParser {
  const WishParser._();

  /// يوحّد الحروف والأرقام قبل المطابقة.
  ///
  /// الهمزات تُردّ إلى الألف، والتاء المربوطة إلى الهاء، والألف المقصورة
  /// إلى الياء، والتشكيل يُحذف، والأرقام العربية-الهندية تصير لاتينية.
  /// هذا ليس تجميلًا: بدونه تفشل نصف المطابقات على كتابة التاجر الفعلية.
  static String normalize(String input) {
    final b = StringBuffer();
    for (final r in input.runes) {
      // التشكيل والتطويل يُحذفان.
      if ((r >= 0x064B && r <= 0x0652) || r == 0x0640) continue;
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(0x0030 + (r - 0x0660)); // ٠-٩
        continue;
      }
      if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(0x0030 + (r - 0x06F0)); // ۰-۹ الفارسية
        continue;
      }
      final c = String.fromCharCode(r);
      b.write(switch (c) {
        'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
        'ة' => 'ه',
        'ى' => 'ي',
        'ؤ' => 'و',
        'ئ' => 'ي',
        '٪' => '%',
        _ => c,
      });
    }
    return b.toString().toLowerCase();
  }

  static const _offerWords = <WishOffer, List<String>>{
    WishOffer.discount: [
      'خصم', 'تخفيض', 'عرض', 'عروض', 'اوفر', 'وفر', 'نص السعر',
      'sale', 'discount', 'off',
    ],
    WishOffer.opening: [
      'افتتاح', 'افتتحنا', 'فرع جديد', 'نفتتح', 'اليوم الاول',
      'opening', 'grand',
    ],
    WishOffer.newItem: [
      'وصل', 'جديد', 'منتج جديد', 'اضفنا', 'تشكيله', 'صنف جديد',
      'new', 'arrival',
    ],
    WishOffer.hiring: [
      'نطلب موظف', 'وظيفه', 'وظائف', 'توظيف', 'مطلوب موظف', 'نبحث عن',
      'hiring', 'vacancy',
    ],
    WishOffer.delivery: [
      'توصيل', 'دليفري', 'مجاني', 'يوصلك', 'delivery',
    ],
    WishOffer.season: [
      'رمضان', 'العيد', 'عيد', 'اليوم الوطني', 'موسم', 'الشتاء', 'الصيف',
      'ramadan', 'eid',
    ],
  };

  static const _toneWords = <String, List<String>>{
    'فخم': ['فخم', 'راقي', 'انيق', 'هادي', 'هادئ', 'luxury', 'elegant'],
    'حماسي': ['مرح', 'حماسي', 'قوي', 'صاخب', 'ناري', 'fun', 'bold'],
    'ودود': ['ودود', 'بسيط', 'عائلي', 'دافي', 'friendly'],
    'جاد': ['جاد', 'رسمي', 'مهني', 'professional', 'formal'],
  };

  static const _urgentWords = [
    'اليوم', 'الان', 'اخر يوم', 'لفترة محدوده', 'لفتره محدوده', 'ينتهي',
    'سارع', 'بسرعه', 'today', 'now', 'last day',
  ];

  static const _lightWords = ['فاتح', 'ابيض', 'مضي', 'light', 'white'];
  static const _darkWords = ['داكن', 'غامق', 'اسود', 'dark', 'ليلي'];

  static WishIntent parse(String wish) {
    final n = normalize(wish);

    var offer = WishOffer.general;
    var bestHit = -1;
    _offerWords.forEach((kind, words) {
      for (final w in words) {
        final at = n.indexOf(normalize(w));
        // الأسبق في الجملة أولى: التاجر يبدأ بما يهمّه.
        if (at >= 0 && (bestHit < 0 || at < bestHit)) {
          bestHit = at;
          offer = kind;
        }
      }
    });

    String? tone;
    _toneWords.forEach((label, words) {
      if (tone != null) return;
      if (words.any((w) => n.contains(normalize(w)))) tone = label;
    });

    final light = _lightWords.any(n.contains);
    final dark = _darkWords.any(n.contains);

    return WishIntent(
      offer: offer,
      raw: wish.trim(),
      discountPercent: _percent(n),
      format: _format(n),
      tone: tone,
      wantsLight: light == dark ? null : light,
      urgent: _urgentWords.any((w) => n.contains(normalize(w))),
      subject: _subject(wish),
    );
  }

  /// نسبة الخصم.
  ///
  /// تُقبل «٣٠٪» و«30%» و«خصم 30» و«30 بالمئه». والحدّ الأعلى ٩٠: رقمٌ
  /// أكبر في جملة عربية يكاد يكون سعرًا أو سنة لا نسبة خصم.
  static int? _percent(String n) {
    for (final re in [
      RegExp(r'(\d{1,3})\s*%'),
      RegExp(r'%\s*(\d{1,3})'),
      RegExp(r'(?:خصم|تخفيض|وفر)\s*(?:بنسبه\s*)?(\d{1,3})'),
      RegExp(r'(\d{1,3})\s*(?:بالمئه|بالمايه|في المئه)'),
    ]) {
      final m = re.firstMatch(n);
      if (m == null) continue;
      final v = int.tryParse(m.group(1)!);
      if (v != null && v > 0 && v <= 90) return v;
    }
    return null;
  }

  static const _formatWords = <AdFormat, List<String>>{
    AdFormat.rollUp: ['رول اب', 'رولاب', 'استاند', 'roll up', 'rollup'],
    AdFormat.businessCard: ['كرت', 'كروت', 'بزنس كارد', 'card'],
    AdFormat.banner: ['بنر', 'لوحه', 'banner'],
    AdFormat.flyer: ['فلاير', 'منشور ورقي', 'flyer'],
    AdFormat.sticker: ['استيكر', 'ملصق', 'sticker'],
    AdFormat.story: ['ستوري', 'ريلز', 'سناب', 'story', 'reel'],
    AdFormat.portrait: ['طولي', 'بورتريه'],
    AdFormat.square: ['مربع', 'square'],
  };

  /// كلمات لا تصلح موضوعًا: أدوات ومقاسات ونبرات وأنواع عروض.
  static final _notSubject = <String>{
    ...(_formatWords.values.expand((v) => v).map(normalize)),
    ...(_offerWords.values.expand((v) => v).map(normalize)),
    ...(_toneWords.values.expand((v) => v).map(normalize)),
    ...(_urgentWords.map(normalize)),
    ..._lightWords.map(normalize),
    ..._darkWords.map(normalize),
    'اعلان', 'تصميم', 'صوره', 'صورة', 'منشور', 'اريد', 'ابي', 'ابغى',
    'محل', 'متجري', 'عندي', 'سوي', 'اعمل', 'من', 'في', 'على', 'مع',
    // ظروف زمان ومكان: «لفترة محدودة» إلحاحٌ لا موضوع.
    'فتره', 'مده', 'وقت', 'يوم', 'اسبوع', 'شهر', 'خلفيه', 'الوان', 'لون',
  };

  /// موضوع الإعلان من صيغة «... لِـكذا».
  ///
  /// العربية تُلصق لام الجرّ بالاسم: «لمقهى»، «لعيادة». فنبحث عن أوّل
  /// كلمة بلام لاصقة ليست من كلماتنا المعروفة، ونأخذها مع صفتها إن
  /// تلتها. وما لم يُفهم يُترك فارغًا — تخمينُ موضوعٍ خطأ أسوأ من
  /// الرجوع إلى المنتج المعروف.
  static String? _subject(String wish) {
    // الجملة تُقسَّم على الفواصل أوّلًا ثم على المسافات داخل كل شقّ.
    //
    // الفاصلة حدّ معنويّ: «ستوري لمخبز، خلفية فاتحة» فيها موضوع وطلبُ
    // خلفية، وتجاهلُها يجعل الموضوع «مخبز خلفية». والصفة لا تُضمّ إلا
    // إن كانت في الشقّ نفسه.
    for (final clause in wish.split(RegExp(r'[،,.؛;\n]+'))) {
      final tokens = clause
          .split(RegExp(r'\s+'))
          .where((t) => t.trim().isNotEmpty)
          .toList();

      for (var i = 0; i < tokens.length; i++) {
        final n = normalize(tokens[i]);
        if (!n.startsWith('ل') || n.length < 4) continue;

        final head = tokens[i].substring(1);
        final hn = normalize(head);
        if (_notSubject.contains(hn)) continue;

        final parts = <String>[head];
        if (i + 1 < tokens.length) {
          final next = tokens[i + 1];
          final nn = normalize(next);
          if (nn.length >= 3 &&
              !_notSubject.contains(nn) &&
              !RegExp(r'[0-9%]').hasMatch(nn)) {
            parts.add(next);
          }
        }
        final subject = parts.join(' ').trim();
        if (subject.length >= 3) return subject;
      }
    }
    return null;
  }

  static AdFormat? _format(String n) {
    for (final e in _formatWords.entries) {
      for (final w in e.value) {
        if (n.contains(normalize(w))) return e.key;
      }
    }
    return null;
  }
}
