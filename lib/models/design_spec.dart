/// مواصفة التصميم — اللغة الوسيطة بين الذكاء الاصطناعي والعارض.
///
/// هذه هي القطعة التي تفصل تطبيقنا عن كانفا، وقد تحقّقتُ منها في بنيتهم
/// لا في تخميني: قرأتُ بنرًا حقيقيًّا من واجهتهم فلم أجد صورة، بل عناصر
/// بإحداثيات وأدوار — نصّ بحجمه ولونه، ومستطيل تملؤه صورة. ولهذا يبقى
/// نصّ تصاميمهم قابلًا للتحرير: لم يُطبع في بكسلات قطّ.
///
/// وعندنا اليوم: النموذج اللغوي يُخرج **نصًّا فقط** (عنوان ووصف
/// وهاشتاقات)، والتخطيط مكتوب في Dart في أحد عشر قالبًا. فالذكاء يملأ
/// فراغات ولا يُركّب تكوينًا — ومهما حسّنّا القوالب يبقى العدد أحد عشر.
///
/// هذه المواصفة تقلب ذلك: يُخرج النموذج **تخطيطًا**، ويرسمه العارض. وقتها
/// يصير عدد التكوينات مفتوحًا بلا سطر Dart جديد لكل واحد.
///
/// ثلاثة قرارات في التصميم تستحق التسمية:
///
///   ١) **الإحداثيات كسريّة لا بكسلات.** عنصرٌ عند ‎x=0.08‎ يقع على ثُمن
///      العرض في الكرت وفي الرول أب سواء. البكسلات تربط المواصفة بمقاس
///      واحد، فتلزمنا مواصفة لكل صيغة — وهو ما نهرب منه.
///
///   ٢) **الألوان أدوار لا قيم.** `ColorRole.complement` لا `#E1A83B`.
///      النموذج لا يعرف لون علامة التاجر ولا يجب أن يعرفه: يقول «لون
///      يقفز» وتترجمه اللوحة. ولو أخرج قيمة صريحة لضاعت الهوية.
///
///   ٣) **بلا تداخل في الأدوار.** لكل عنصر دور واحد معروف (عنوان، منتج،
///      زرّ…) فيستطيع المدقّق أن يحكم عليه: العنوان يجب أن يُقرأ، والزرّ
///      يجب أن يُرى، والمنتج لا يُغطّى. دورٌ مجهول لا يُفحص.
library;

import 'ad_format.dart';

/// دور العنصر — عليه تُبنى أحكام المدقّق وأولويات الإصلاح.
enum ElementRole {
  headline,
  subhead,
  product,
  cta,
  badge,
  logo,
  tags,

  /// شكل زخرفي (شريط، دائرة، لوح خلف نصّ).
  shape,

  /// زخرفة ركن — رسمٌ متجهيّ مستوحى من نشاط التاجر، يُرسم خافتًا خلف
  /// المحتوى. المواصفة تقول **أين**، والعارض يُعطى **أيّ رسم** كما
  /// يُعطى صورةَ المنتج وشعارَ العلامة: النموذج لا يعرف ملفّات مشروعنا.
  ///
  /// وليست `shape` بلوح: اللوح معتم يحجب، وهذه شفّافة لا تحجب — والفرق
  /// يقرّره الطبيب حين يقيس الحجب.
  ornament,
}

/// اللون كدور في اللوحة لا كقيمة.
enum ColorRole {
  base,
  deep,
  complement,
  neutral,

  /// لون الموسم الذي اختاره التاجر (أخضر اليوم الوطني، ذهبيّ رمضان…).
  ///
  /// دورٌ لا قيمة، كبقيّة الألوان: المواصفة تقول «لون الموسم» ويترجمه
  /// من يعرف أيّ موسمٍ اختير. وبلا موسم يسقط إلى `complement` فلا يبقى
  /// عنصرٌ بلا لون.
  season,

  /// حبر مقروء فوق ما تحته — يحسبه العارض بالتباين.
  auto,
}

/// محاذاة النصّ. لا نستعمل `TextAlign` من Flutter هنا: المواصفة يجب أن
/// تبقى بلا اعتماد على مكتبة الرسم لتُرسَل وتُخزَّن وتُختبر بلا إطار.
enum SpecAlign { start, center, end }

/// مستطيل بإحداثيات كسريّة من اللوحة (٠ إلى ١).
class SpecRect {
  const SpecRect(this.x, this.y, this.w, this.h);

  final double x, y, w, h;

  double get right => x + w;
  double get bottom => y + h;

  bool overlaps(SpecRect o) =>
      x < o.right && o.x < right && y < o.bottom && o.y < bottom;

  /// مساحة التقاطع ككسر من مساحة الأصغر — «تلامس» أم «تغطية»؟
  double overlapRatio(SpecRect o) {
    final iw = (right < o.right ? right : o.right) - (x > o.x ? x : o.x);
    final ih = (bottom < o.bottom ? bottom : o.bottom) - (y > o.y ? y : o.y);
    if (iw <= 0 || ih <= 0) return 0;
    final mine = w * h, theirs = o.w * o.h;
    final smaller = mine < theirs ? mine : theirs;
    return smaller <= 0 ? 0 : (iw * ih) / smaller;
  }

  /// يعيد المستطيل داخل الهامش الآمن.
  ///
  /// الحدّان يُحسبان ثم يُضبطان قبل `clamp`: حين يملأ العنصر كل المساحة
  /// المتاحة يصير الحدّ الأعلى مساويًا للأدنى نظريًّا، لكنه يخرج أصغر
  /// منه بمقدار فاصلة عائمة (‎1 − 0.062 − 0.876 = 0.06199…‎) فيرمي
  /// `clamp` استثناءً. وهذا ليس تنميقًا: العنصر الممتدّ على كامل العرض
  /// هو الحال الشائع في تصاميم الاستاند، فكان يسقط دائمًا.
  SpecRect clampInside(double margin) {
    final maxSpan = 1 - margin * 2;
    final nw = w.clamp(0.02, maxSpan);
    final nh = h.clamp(0.02, maxSpan);
    final maxX = 1 - margin - nw;
    final maxY = 1 - margin - nh;
    return SpecRect(
      maxX <= margin ? margin : x.clamp(margin, maxX),
      maxY <= margin ? margin : y.clamp(margin, maxY),
      nw,
      nh,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory SpecRect.fromJson(Map<String, dynamic> j) => SpecRect(
    (j['x'] as num?)?.toDouble() ?? 0,
    (j['y'] as num?)?.toDouble() ?? 0,
    (j['w'] as num?)?.toDouble() ?? 1,
    (j['h'] as num?)?.toDouble() ?? 1,
  );

  @override
  String toString() =>
      'Rect(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, '
      '${w.toStringAsFixed(3)}, ${h.toStringAsFixed(3)})';
}

/// عنصر واحد في التصميم.
class DesignElement {
  const DesignElement({
    required this.role,
    required this.rect,
    this.text,
    this.color = ColorRole.auto,
    this.fill,
    this.align = SpecAlign.start,
    this.maxLines = 2,

    /// حجم الحرف ككسر من عرض اللوحة. `null` يترك التقدير للعارض.
    ///
    /// كسرٌ لا نقطة، للسبب نفسه الذي جعل الإحداثيات كسريّة. والقيمة
    /// المرجعية من تشريح كانفا: العنوان ≈ ٤٫٩٪ من العرض.
    this.sizeFactor,
    this.weight = 700,
  });

  final ElementRole role;
  final SpecRect rect;
  final String? text;

  /// لون المحتوى (الحروف أو الحدّ).
  final ColorRole color;

  /// لون اللوح خلف العنصر. `null` يعني بلا لوح — يجلس على الخلفية.
  final ColorRole? fill;

  final SpecAlign align;
  final int maxLines;
  final double? sizeFactor;
  final int weight;

  bool get isText =>
      role == ElementRole.headline ||
      role == ElementRole.subhead ||
      role == ElementRole.cta ||
      role == ElementRole.badge ||
      role == ElementRole.tags;

  DesignElement copyWith({
    ElementRole? role,
    SpecRect? rect,
    String? text,
    ColorRole? color,
    ColorRole? fill,
    SpecAlign? align,
    int? maxLines,
    double? sizeFactor,
    int? weight,
  }) => DesignElement(
    role: role ?? this.role,
    rect: rect ?? this.rect,
    text: text ?? this.text,
    color: color ?? this.color,
    fill: fill ?? this.fill,
    align: align ?? this.align,
    maxLines: maxLines ?? this.maxLines,
    sizeFactor: sizeFactor ?? this.sizeFactor,
    weight: weight ?? this.weight,
  );

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'rect': rect.toJson(),
    if (text != null) 'text': text,
    'color': color.name,
    if (fill != null) 'fill': fill!.name,
    'align': align.name,
    'maxLines': maxLines,
    if (sizeFactor != null) 'sizeFactor': sizeFactor,
    'weight': weight,
  };

  /// يقرأ عنصرًا من JSON النموذج.
  ///
  /// كل حقل مجهول يعود إلى قيمة آمنة ولا يُسقط المواصفة: النموذج اللغوي
  /// يخترع أسماءً أحيانًا («title» بدل «headline»)، وإسقاطُ تصميم كامل
  /// بسبب كلمة أهون من إسقاطه بلا سبب مفهوم — والمدقّق يُبلّغ لاحقًا.
  factory DesignElement.fromJson(Map<String, dynamic> j) => DesignElement(
    role: _enumFrom(ElementRole.values, j['role']) ?? ElementRole.shape,
    rect: SpecRect.fromJson(
      (j['rect'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    text: j['text'] as String?,
    color: _enumFrom(ColorRole.values, j['color']) ?? ColorRole.auto,
    fill: _enumFrom(ColorRole.values, j['fill']),
    align: _enumFrom(SpecAlign.values, j['align']) ?? SpecAlign.start,
    maxLines: (j['maxLines'] as num?)?.toInt().clamp(1, 6) ?? 2,
    // الحجم كسر من عرض اللوحة، ويُقيَّد هنا لا في العارض: النموذج يُخرج
    // أحيانًا ٠٫٥ أو ١٢ (يظنّها نقاطًا)، فيخرج حرفٌ أطول من اللوحة كلّها.
    // و`ArtText` يُصغّر ما يفيض لكنه لا يُكبّر ما ضؤل، فحرفٌ عند ٠٫٠٠١
    // يخرج نقطةً لا تُقرأ ولا بلاغ.
    sizeFactor: (j['sizeFactor'] as num?)?.toDouble().clamp(0.012, 0.22),
    weight: (j['weight'] as num?)?.toInt().clamp(100, 900) ?? 700,
  );
}

/// نمط الخلفية كما يطلبه النموذج. مطابق لأنماط `ArtBackdrop` لكن معرّف
/// هنا لتبقى المواصفة مستقلّة عن طبقة الرسم.
enum SpecBackdrop { mesh, spotlight, arcs, strata, paper }

extension SpecBackdropInfo on SpecBackdrop {
  /// هل الخلفية فاتحة؟ يحدّد الحبر الافتراضي فوقها.
  bool get isLight => this == SpecBackdrop.paper;
}

/// تصميم كامل.
class DesignSpec {
  const DesignSpec({
    required this.format,
    required this.backdrop,
    required this.elements,
    this.variant = 0,
    this.note,
  });

  final AdFormat format;
  final SpecBackdrop backdrop;
  final List<DesignElement> elements;

  /// رقم الانسجام اللوني — يُمرَّر إلى `ArtPalette.from`.
  final int variant;

  /// شرح النموذج لاختياره. يُعرض للتاجر ويُفيد في التشخيص حين يخرج
  /// تصميم رديء: نعرف ما ظنّ أنه يفعل.
  final String? note;

  Map<String, dynamic> toJson() => {
    'format': format.name,
    'backdrop': backdrop.name,
    'variant': variant,
    if (note != null) 'note': note,
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  factory DesignSpec.fromJson(Map<String, dynamic> j) => DesignSpec(
    format:
        _enumFrom(AdFormat.values, j['format']) ?? AdFormat.square,
    backdrop: _enumFrom(SpecBackdrop.values, j['backdrop']) ?? SpecBackdrop.mesh,
    variant: (j['variant'] as num?)?.toInt() ?? 0,
    note: j['note'] as String?,
    elements: ((j['elements'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => DesignElement.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );

  DesignSpec withElements(List<DesignElement> next) => DesignSpec(
    format: format,
    backdrop: backdrop,
    elements: next,
    variant: variant,
    note: note,
  );

  DesignElement? firstOf(ElementRole role) {
    for (final e in elements) {
      if (e.role == role) return e;
    }
    return null;
  }

  int indexOf(ElementRole role) {
    for (var i = 0; i < elements.length; i++) {
      if (elements[i].role == role) return i;
    }
    return -1;
  }

  /// يبدّل عنصرًا بفهرسه. فهرس خارج المدى يعيد المواصفة كما هي بدل أن
  /// يرمي: المحرّر يعمل على نسخة قد تتغيّر تحته، وانهيارٌ في يد التاجر
  /// أسوأ من تعديل ضاع.
  DesignSpec replaceAt(int index, DesignElement e) {
    if (index < 0 || index >= elements.length) return this;
    final next = [...elements];
    next[index] = e;
    return withElements(next);
  }

  /// يكتب نصًّا في أوّل عنصر بهذا الدور. لا يُنشئ عنصرًا حين يغيب الدور:
  /// موضعُ عنصرٍ جديد قرارُ تكوين، والمحرّر لا يخترع تكوينًا.
  DesignSpec withRoleText(ElementRole role, String text) {
    final i = indexOf(role);
    if (i < 0) return this;
    return replaceAt(i, elements[i].copyWith(text: text));
  }
}

T? _enumFrom<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  final name = raw.trim();
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
