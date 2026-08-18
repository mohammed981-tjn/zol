/// صيغ الإعلان — اللوحة قبل التصميم.
///
/// كانت الصيغة ثلاث سلاسل نصّية («منشور مربع»، «ستوري»، «ريلز») ونسبةً
/// تُشتقّ منها بمقارنة نصّية، والمقياس كلّه `العرض ÷ ٤٠٠` أي مربّع
/// مفترَض. أثر ذلك أن التطبيق **يبيع طباعة لا يستطيع تصميمها**: كتالوج
/// الطباعة فيه رول أب ‎85×200‎ وكرت ‎9×5‎ وبنر ‎1×2‎ متر، ومحرّك التصميم
/// يرسم لها جميعًا مربّعًا واحدًا ثم تُقصّ عند الطباعة.
///
/// وهذا ليس نقصًا في القوالب بل في **اللوحة**: الكرت ليس منشورًا صغيرًا،
/// والرول أب ليس منشورًا ممدودًا. لكلٍّ نسبة ومسافة قراءة وحجم حرف
/// مختلف، والقالب الواحد لا يصلح لها ما لم يعرف على أيّها يرسم.
library;

/// نسبة أبعاد اللوحة وسلوكها.
enum AdFormat {
  /// منشور مربّع — إنستغرام وسناب.
  square,

  /// منشور طولي ‎4:5‎ — الصيغة التي تحتلّ أكبر مساحة في خطّ إنستغرام،
  /// وهي التي وجدتُها مستعملة في تصاميم كانفا الحقيقية لا المربّع.
  portrait,

  /// ستوري / ريلز ‎9:16‎.
  story,

  /// كرت أعمال ‎9×5‎ سم — أفقي وصغير.
  businessCard,

  /// استاند رول أب ‎85×200‎ سم — طويل جدًّا ويُقرأ من بعيد.
  rollUp,

  /// بنر أفقي ‎2×1‎ متر.
  banner,

  /// استيكر مربّع.
  sticker,

  /// فلاير ‎A5‎ (‎148×210‎ ملم).
  flyer,
}

/// صنف الشكل — عليه تُبنى قرارات التخطيط لا على الصيغة نفسها.
///
/// القالب لا يحتاج أن يعرف «كرت أعمال» من «بنر»؛ يكفيه أن يعرف أن
/// اللوحة عريضة فيصفّ أفقيًّا بدل أن يكدّس عموديًّا. هذا يمنع انفجار
/// العدد: ثمانية صيغ × أحد عشر قالبًا لا تعني ٨٨ تخطيطًا.
enum AspectClass {
  /// أطول من ‎1:1.6‎ — رول أب وستوري.
  tall,

  /// بين المربّع و‎1:1.6‎ — المنشور الطولي والفلاير.
  portrait,

  /// مربّع تقريبًا.
  square,

  /// أعرض من ‎1.25:1‎ — الكرت والبنر.
  wide,
}

extension AdFormatInfo on AdFormat {
  String get label => switch (this) {
    AdFormat.square => 'منشور مربع',
    AdFormat.portrait => 'منشور طولي',
    AdFormat.story => 'ستوري',
    AdFormat.businessCard => 'كرت أعمال',
    AdFormat.rollUp => 'استاند رول أب',
    AdFormat.banner => 'بنر',
    AdFormat.sticker => 'استيكر',
    AdFormat.flyer => 'فلاير A5',
  };

  /// المقاس الحقيقي كما يفهمه التاجر والمطبعة.
  String get sizeHint => switch (this) {
    AdFormat.square => '١٠٨٠ × ١٠٨٠ بكسل',
    AdFormat.portrait => '١٠٨٠ × ١٣٥٠ بكسل',
    AdFormat.story => '١٠٨٠ × ١٩٢٠ بكسل',
    AdFormat.businessCard => '٩ × ٥ سم',
    AdFormat.rollUp => '٨٥ × ٢٠٠ سم',
    AdFormat.banner => '٢ × ١ متر',
    AdFormat.sticker => '١٠ × ١٠ سم',
    AdFormat.flyer => '١٤٨ × ٢١٠ ملم',
  };

  /// العرض ÷ الارتفاع. الأرقام من مقاسات كتالوج الطباعة نفسه، فما يراه
  /// التاجر في المعاينة هو ما يخرج من المطبعة.
  double get aspect => switch (this) {
    AdFormat.square => 1,
    AdFormat.portrait => 1080 / 1350,
    AdFormat.story => 9 / 16,
    AdFormat.businessCard => 9 / 5,
    AdFormat.rollUp => 85 / 200,
    AdFormat.banner => 2 / 1,
    AdFormat.sticker => 1,
    AdFormat.flyer => 148 / 210,
  };

  AspectClass get aspectClass {
    final a = aspect;
    if (a >= 1.25) return AspectClass.wide;
    if (a >= 0.92) return AspectClass.square;
    if (a >= 0.625) return AspectClass.portrait;
    return AspectClass.tall;
  }

  /// هل تُطبَع؟ يحدّد الهامش الآمن ووجود حدّ القصّ.
  bool get isPrint => switch (this) {
    AdFormat.businessCard ||
    AdFormat.rollUp ||
    AdFormat.banner ||
    AdFormat.sticker ||
    AdFormat.flyer => true,
    _ => false,
  };

  /// اسم المنتج المقابل في كتالوج الطباعة — الرابط بين ما يصمّمه التاجر
  /// وما يطلبه. `null` يعني صيغة رقمية لا تُطبع.
  String? get printProduct => switch (this) {
    AdFormat.businessCard => 'كروت أعمال',
    AdFormat.rollUp => 'رول أب',
    AdFormat.banner => 'بنر',
    AdFormat.sticker => 'استيكرات',
    AdFormat.flyer => 'فلايرات',
    _ => null,
  };

  /// الهامش الآمن ككسر من أصغر ضلع.
  ///
  /// ٣٫٨٪ في الرقمي — وهو ما قِسته في بنر كانفا حقيقي (٤١ من ١٠٨٠).
  /// وأوسع في المطبوع: سكّين القصّ لا تقع على الخطّ تمامًا، وكلّ ما
  /// قارب الحافّة قد يُقصّ. هذا الرقم هو الفرق بين شعارٍ كامل وشعارٍ
  /// مقصوص نصفه في ألف نسخة مطبوعة.
  double get safeMargin => isPrint ? 0.062 : 0.038;

  /// معامل حجم الحرف. الحجم نسبة من العرض دائمًا، لكن مسافة القراءة
  /// تختلف: الرول أب يُقرأ من ثلاثة أمتار فيحتاج حرفًا أكبر نسبيًّا،
  /// والكرت يُمسك باليد ويحمل معلومات كثيرة على سطح صغير.
  double get typeScale => switch (this) {
    AdFormat.rollUp => 1.34,
    AdFormat.banner => 1.22,
    AdFormat.story => 1.1,
    AdFormat.businessCard => 0.66,
    AdFormat.sticker => 0.86,
    AdFormat.flyer => 0.94,
    _ => 1.0,
  };

  /// وصف قصير يشرح للتاجر متى يختارها — أكثر التجّار لا يعرف الفرق بين
  /// «بنر» و«رول أب» قبل أن يقف أمام المطبعة.
  String get useWhen => switch (this) {
    AdFormat.square => 'الأكثر أمانًا: يظهر كاملًا في كل المنصّات',
    AdFormat.portrait => 'يحتلّ مساحة أكبر في خطّ إنستغرام فيلفت أكثر',
    AdFormat.story => 'شاشة كاملة في ستوري سناب وإنستغرام',
    AdFormat.businessCard => 'يُوزَّع باليد ويبقى في المحفظة',
    AdFormat.rollUp => 'يقف بجانب بابك أو في معرض',
    AdFormat.banner => 'يُعلَّق على واجهة أو سور',
    AdFormat.sticker => 'على العبوة أو الكيس أو السيارة',
    AdFormat.flyer => 'يُوزَّع في الحيّ أو يوضع على الطاولات',
  };
}

/// يحوّل نصّ الصيغة المحفوظ إلى صيغة معروفة.
///
/// الإعلانات المحفوظة على أجهزة التجّار تحمل النصّ القديم، فلا يجوز
/// كسرها: أي نصّ غير معروف يعود إلى المربّع وهو أسلم الصيغ.
AdFormat adFormatFromLabel(String? label) {
  if (label == null) return AdFormat.square;
  for (final f in AdFormat.values) {
    if (f.label == label) return f;
  }
  return switch (label) {
    'ريلز' => AdFormat.story,
    'منشور مربّع' => AdFormat.square,
    _ => AdFormat.square,
  };
}
