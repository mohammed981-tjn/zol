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
      // محارف التوجيه والتحكّم غير المرئية: واتساب يلصقها مع النصّ
      // المنسوخ، فتمنع المطابقة بلا أن يرى التاجر شيئًا يفسّر ذلك.
      if (r == 0x200B || r == 0x200C || r == 0x200D ||
          r == 0x200E || r == 0x200F || r == 0x061C ||
          (r >= 0x202A && r <= 0x202E) ||
          (r >= 0x2066 && r <= 0x2069) ||
          r == 0xFEFF) {
        continue;
      }
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
    // «مجاني» وحدها ليست توصيلًا: «استشارة مجانية لعيادة» كانت تُخرج
    // «توصيل مجاني — يصلك عيادة إلى بابك».
    WishOffer.delivery: [
      'توصيل', 'دليفري', 'يوصلك', 'نوصل لك', 'delivery',
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

  /// أدوات ولواصق تسبق الكلمة في العربية فلا تمنع المطابقة.
  static const _prefixes = ['و', 'ف', 'ب', 'ل', 'ك', 'ال', 'وال', 'بال', 'لل'];

  /// كلمات النفي: وجودها قبل الكلمة يقلب معناها.
  static const _negations = [
    'بدون', 'بلا', 'مابي', 'مابغى', 'ما', 'لا', 'مو', 'مب', 'ليس', 'غير',
    'no', 'without', 'not',
  ];

  /// موضع الكلمة **ككلمة كاملة** لا كجزء من كلمة.
  ///
  /// كان البحث بـ`contains`، فتطابق «عرض» داخل «مَعرض»، و«عيد» داخل
  /// «مواعيد»، و«off» داخل «coffee»، و«مرح» داخل «مرحبا». فيخرج لمعرض
  /// سيارات إعلانُ خصم، ولعيادة أسنان إعلانٌ موسميّ.
  ///
  /// والمقارنة على الكلمة كاملة بعد نزع اللواصق: العربية تُلصق «و» و«ال»
  /// و«ب» بالكلمة، فمطابقةٌ صارمة تمامًا تفوت «والخصم» و«بالتوصيل».
  static int _wordHit(List<String> tokens, String phrase) {
    final want = normalize(phrase).split(RegExp(r'\s+'));
    for (var i = 0; i + want.length <= tokens.length; i++) {
      var all = true;
      for (var k = 0; k < want.length; k++) {
        if (!_tokenMatches(tokens[i + k], want[k])) {
          all = false;
          break;
        }
      }
      if (all) return i;
    }
    return -1;
  }

  /// لواحق الصرف: التأنيث والجمع. «فاتحة» هي «فاتح»، و«جديدة» هي
  /// «جديد». وبلا هذه تفشل المطابقة على أكثر ما يكتبه التاجر.
  static const _suffixes = ['ه', 'ات', 'ين', 'ون', 'يه', 'تين'];

  static bool _tokenMatches(String token, String want) {
    // الطرفان يُجرّدان معًا: تجريدُ أحدهما وحده يمنع «لفتره» من مطابقة
    // «لفتره» نفسها لأن اللاحقة سقطت من طرف وبقيت في الآخر.
    final w = _strip(want);
    if (token == want || _strip(token) == w) return true;
    for (final p in _prefixes) {
      if (token.length > p.length && token.startsWith(p)) {
        final rest = token.substring(p.length);
        if (rest == want || _strip(rest) == w) return true;
      }
    }
    return false;
  }

  /// يجرّب الكلمة كما هي وبلا لاحقة.
  ///
  /// والجذع الباقي يجب أن يبلغ أربعة أحرف: تجريدٌ أقصر يقطع كلماتٍ
  /// لاحقتُها من بنيتها. «كرتون» بلا «ون» تصير «كرت» — فعلبةُ كرتون
  /// كانت تُفهم كرتَ أعمال ‎9×5‎ سم.
  static String _strip(String t) {
    for (final suf in _suffixes) {
      if (t.endsWith(suf) && t.length - suf.length >= 4) {
        return t.substring(0, t.length - suf.length);
      }
    }
    return t;
  }

  static bool _negatedAt(List<String> tokens, int at) {
    for (var k = at - 2; k < at; k++) {
      if (k < 0) continue;
      if (_negations.any((w) => _tokenMatches(tokens[k], normalize(w)))) {
        return true;
      }
    }
    return false;
  }

  static List<String> _tokens(String n) => n
      .split(RegExp(r'[^\p{L}\p{N}%]+', unicode: true))
      .where((t) => t.isNotEmpty)
      .toList();

  static WishIntent parse(String wish) {
    final n = normalize(wish);
    final tokens = _tokens(n);

    var offer = WishOffer.general;
    var bestHit = -1;
    _offerWords.forEach((kind, words) {
      for (final w in words) {
        final at = _wordHit(tokens, w);
        if (at < 0) continue;
        // «بدون خصم» ليست طلب خصم: التاجر يقول صراحةً ما لا يريد.
        if (_negatedAt(tokens, at)) continue;
        // الأسبق في الجملة أولى: التاجر يبدأ بما يهمّه.
        if (bestHit < 0 || at < bestHit) {
          bestHit = at;
          offer = kind;
        }
      }
    });

    String? tone;
    _toneWords.forEach((label, words) {
      if (tone != null) return;
      if (words.any((w) => _wordHit(tokens, w) >= 0)) tone = label;
    });

    final light = _lightWords.any((w) => _wordHit(tokens, w) >= 0);
    final dark = _darkWords.any((w) => _wordHit(tokens, w) >= 0);

    return WishIntent(
      offer: offer,
      raw: wish.trim(),
      discountPercent: _percent(n),
      format: _format(tokens),
      tone: tone,
      wantsLight: light == dark ? null : light,
      urgent: _urgentWords.any((w) => _wordHit(tokens, w) >= 0),
      subject: _subject(wish),
    );
  }

  /// نسبة الخصم.
  ///
  /// تُقبل «٣٠٪» و«30%» و«خصم 30» و«30 بالمئه». والحدّ الأعلى ٩٠: رقمٌ
  /// أكبر في جملة عربية يكاد يكون سعرًا أو سنة لا نسبة خصم.
  static int? _percent(String n) {
    // علامة النسبة **مشترَطة**.
    //
    // كان النمط يقبل «خصم ١٥» مجرّدًا، فيقرأ «خصم ١٥ ريال على كل وجبة»
    // خمسةَ عشر بالمئة ويطبعها على رول أب. وهذا خطأ تجاريّ لا تجميليّ:
    // ورقةٌ مطبوعة تَعِد بما لم يقله التاجر ولا تُسترجَع.
    for (final re in [
      RegExp(r'(\d{1,3})\s*%'),
      RegExp(r'%\s*(\d{1,3})'),
      RegExp(r'(\d{1,3})\s*(?:بالمئه|بالمايه|بالميه|في المئه|percent)'),
    ]) {
      for (final m in re.allMatches(n)) {
        // ورقمٌ تليه عملة ليس نسبة مهما سبقته كلمة «خصم».
        final after = n.substring(m.end).trimLeft();
        if (RegExp(r'^(ريال|ر\.?س|sar|درهم|دولار)').hasMatch(after)) continue;
        final v = int.tryParse(m.group(1)!);
        if (v != null && v > 0 && v <= 90) return v;
      }
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

  /// كلمات شائعة تبدأ بلام أصلية من بنيتها لا بلام جرّ.
  ///
  /// «لدينا» ليست «دينا»، و«لوحة» ليست «وحة»، و«لازم» ليست «ازم».
  /// وبلا هذه القائمة كان الموضوع يُقصّ من أوّل الكلمة فيُطبع عنوانًا:
  /// «عرض خاص على دينا».
  static const _lamWords = <String>{
    'لدينا', 'لازم', 'لوحه', 'لوحة', 'لاننا', 'لكن', 'لكني',
    'لماذا', 'لعل', 'ليس', 'لهم', 'لنا', 'لكم', 'لها', 'له', 'لي',
    'لان', 'لانه', 'لانها', 'لو', 'لولا', 'لقد', 'لطيف', 'لطيفه',
    'لون', 'لوني', 'لايك', 'لحم', 'لبن', 'لعبه', 'لغه', 'لحظه',
  };

  /// ينظّف الكلمة للعرض: يحذف التشكيل والتطويل ومحارف التحكّم ويُبقي
  /// الحروف كما كتبها التاجر (فـ«مقهى» تبقى «مقهى» لا «مقهي»).
  static String _clean(String w) {
    final b = StringBuffer();
    for (final r in w.runes) {
      if ((r >= 0x064B && r <= 0x0652) || r == 0x0640) continue;
      if (r == 0x200B || r == 0x200C || r == 0x200D ||
          r == 0x200E || r == 0x200F || r == 0x061C ||
          (r >= 0x202A && r <= 0x202E) ||
          (r >= 0x2066 && r <= 0x2069) ||
          r == 0xFEFF) {
        continue;
      }
      b.writeCharCode(r);
    }
    return b.toString().trim();
  }

  /// موضوع الإعلان من صيغة «... لِـكذا».
  ///
  /// العربية تُلصق لام الجرّ بالاسم: «لمقهى»، «لعيادة»، «للمخبز». فنبحث
  /// عن أوّل كلمة بلام لاصقة ليست من كلماتنا المعروفة ولا من الكلمات
  /// التي لامها من بنيتها، ونأخذها مع صفتها إن تلتها في الشقّ نفسه.
  ///
  /// وما لم يُفهم يُترك فارغًا — تخمينُ موضوعٍ خطأ أسوأ من الرجوع إلى
  /// المنتج المعروف، لأنه يُطبع عنوانًا.
  static String? _subject(String wish) {
    for (final clause in wish.split(RegExp(r'[،,.؛;\n]+'))) {
      final tokens = clause
          .split(RegExp(r'\s+'))
          .map(_clean)
          .where((t) => t.isNotEmpty)
          .toList();

      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        final n = normalize(token);
        if (!n.startsWith('ل') || n.length < 4) continue;
        if (_lamWords.contains(n)) continue;

        // «للمخبز» لامان: لام جرّ ولام التعريف. وقصُّ واحدة يُبقي «لمخبز».
        final cut = n.startsWith('لل') ? 2 : 1;
        final head = _clean(token.substring(cut));
        if (head.length < 3) continue;
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

  static AdFormat? _format(List<String> tokens) {
    AdFormat? best;
    var bestAt = -1;
    for (final e in _formatWords.entries) {
      for (final w in e.value) {
        final at = _wordHit(tokens, w);
        if (at >= 0 && (bestAt < 0 || at < bestAt)) {
          bestAt = at;
          best = e.key;
        }
      }
    }
    return best;
  }
}
