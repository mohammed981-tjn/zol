import 'dart:math' as math;
import 'dart:ui';

import '../models/ad_format.dart';
import '../models/design_spec.dart';
import '../theme/art_palette.dart';
import '../theme/spec_palette.dart';
import 'spec_doctor.dart';

/// درجة تصميم مفصَّلة — لا رقمًا واحدًا مبهمًا.
///
/// التفصيل مقصود: رقمٌ واحد يقول «٦٢» لا يُعلّم أحدًا شيئًا، ولا يُمكّننا
/// من معرفة أي بند تدهور حين تسوء المخرَجات. وهذه البنود هي التي
/// تُعرَض في وضع التشخيص وتُختبَر واحدًا واحدًا.
class DesignScore {
  const DesignScore({required this.parts, required this.blocked});

  /// اسم البند ← درجته من ٠ إلى ١.
  final Map<String, double> parts;

  /// علل الطبيب التي لم تُصلَح. وجودها يعني أن التصميم لا يُعرض أصلًا.
  final List<SpecIssue> blocked;

  bool get usable => blocked.isEmpty;

  /// المجموع الموزون من ١٠٠. المحجوب يأخذ صفرًا لا درجةً منخفضة: تصميمٌ
  /// لا يُقرأ عنوانه ليس «أقلّ جودة» بل غير صالح.
  double get total {
    if (!usable) return 0;
    var sum = 0.0, weight = 0.0;
    DesignCritic.weights.forEach((k, w) {
      sum += (parts[k] ?? 0) * w;
      weight += w;
    });
    return weight == 0 ? 0 : (sum / weight) * 100;
  }

  @override
  String toString() {
    final p = parts.entries
        .map((e) => '${e.key}=${e.value.toStringAsFixed(2)}')
        .join(' ');
    return '${total.toStringAsFixed(1)} [$p]${usable ? '' : ' ✖محجوب'}';
  }
}

/// ناقد التصميم — الطبقة التي تجعل التوليد المحلّي **ذكاءً** لا عشوائية.
///
/// المولّد يستطيع أن يُخرج آلاف التكوينات في جزء من الثانية. وهذا بلا
/// قيمة وحده: تكوينٌ عشوائي أسوأ من قالبٍ ثابت. القيمة تأتي من **الحكم**
/// — أن نقيس كل تكوين بمعايير تصميم حقيقية ونختار أعلاها.
///
/// وهذا ما يفعله المصمّم البشري حين ينظر إلى عمله ويُبعده عن عينيه: لا
/// يخترع قواعد جديدة، بل يفحص القائمة نفسها — هل التسلسل واضح؟ هل
/// اللوحة متوازنة؟ هل الحواف مصطفّة؟ هل الفراغ كافٍ؟
///
/// والفرق بين هذا الناقد و`SpecDoctor` فرقٌ في الطبيعة لا في الدرجة:
/// الطبيب يحكم بـ**نعم/لا** على ما لا يجوز (نصّ لا يُقرأ، عنصر خارج
/// الهامش)، والناقد يحكم بـ**درجة** على ما هو أجمل. فالطبيب بوّابة
/// والناقد مفاضلة، ولا يُغني أحدهما عن الآخر.
class DesignCritic {
  const DesignCritic._();

  /// أوزان البنود. مجموعها لا يهمّ — تُطبَّع في الحساب.
  ///
  /// التسلسل أثقلها: إعلانٌ متوازن الفراغ بلا تسلسل بصري لا يُقرأ من
  /// بعيد، والرول أب يُقرأ من ثلاثة أمتار. والاصطفاف يليه لأنه أظهر فرق
  /// بين «مصمَّم» و«مركَّب».
  static const weights = <String, double>{
    'hierarchy': 2.2,
    'alignment': 1.8,
    'balance': 1.4,
    'whitespace': 1.3,
    'formatFit': 1.2,
    'rhythm': 1.0,
    'focus': 0.9,
    'intact': 0.9,
  };

  /// تسامح اعتبار حافّتين مصطفّتين — ١٪ من اللوحة.
  static const _edgeTolerance = 0.012;

  /// هل يرسم العارض هذا العنصر أصلًا؟
  ///
  /// `shape` بلا `fill` لا يُرسم له شيء، ونصٌّ فارغ لا يظهر. وحسابُهما
  /// يفتح بابًا لخداع الدرجة بعناصر «شبح»: أربعة وعشرون شكلًا لا يُرى
  /// منها شيء رفعت الاصطفاف من ٠٫٤٠ إلى ٠٫٨٦ وأضافت تسع درجات.
  /// والزخرفة تُرسم لكنها **ليست محتوى**: ركنٌ خافت خلف كل شيء. عدُّها
  /// في الاصطفاف والتوازن والفراغ يعاقب التاجرَ على اختياره إيّاها —
  /// حافّة زائدة، وثقل في ركن، ومساحة مشغولة — وهي لا تزاحم شيئًا.
  /// فتُترك للعين لا للميزان، كما تُترك الخلفية.
  static bool _rendered(DesignElement e) {
    if (e.role == ElementRole.ornament) return false;
    if (e.role == ElementRole.shape) return e.fill != null;
    if (e.isText) return (e.text ?? '').trim().isNotEmpty;
    return true;
  }

  /// العناصر المرسومة وحدها.
  static List<DesignElement> _live(DesignSpec s) =>
      s.elements.where(_rendered).toList();

  static DesignScore score(
    DesignSpec spec, {
    required Color brandColor,
    Color? seasonColor,
    // يُمرَّر إلى الطبيب كما يمرّره من يستدعيه مباشرةً. بدونه يفحص
    // الناقدُ نسخةً من المواصفة غير التي فحصها مستدعيه، فيختلف
    // `blocked` عن `blocking` ويصير الترتيب محكومًا بحكمين متغايرين.
    bool hasLogo = false,
  }) {
    final report = SpecDoctor.review(
      spec,
      brandColor: brandColor,
      hasLogo: hasLogo,
      seasonColor: seasonColor,
    );
    final s = report.spec;
    final art = paletteFor(s, brandColor);

    return DesignScore(
      blocked: report.blocking,
      parts: {
        'hierarchy': _hierarchy(s),
        'alignment': _alignment(s),
        'balance': _balance(s),
        'whitespace': _whitespace(s),
        'formatFit': _formatFit(s),
        'rhythm': _rhythm(s),
        'focus': _focus(s, art),
        'intact': _intact(report),
      },
    );
  }

  /// **التسلسل**: هل يعرف المشاهد بمَ يبدأ؟
  ///
  /// عنوانٌ بحجم سطره الثانوي يجعل العين تتردّد، والتردّد في إعلانٍ يُرى
  /// ثانيتين خسارة. النسبة المرجعية ١٫٦ فأعلى — وهي أدنى ما يُميّز
  /// مستويين في السلالم الطباعية المتعارفة.
  static double _hierarchy(DesignSpec s) {
    final h = s.firstOf(ElementRole.headline);
    if (h == null) return 0;
    final hs = h.sizeFactor ?? 0.049;
    final sub = s.firstOf(ElementRole.subhead);
    final cta = s.firstOf(ElementRole.cta);

    var score = 0.0, n = 0.0;

    if (sub != null) {
      final ratio = hs / (sub.sizeFactor ?? 0.032);
      score += _band(ratio, 1.6, 3.2);
      n++;
    }
    if (cta != null) {
      // زرّ الحثّ لا يزاحم العنوان ولا يختفي: بين ثلث العنوان ونصفه.
      final ratio = (cta.sizeFactor ?? 0.030) / hs;
      score += _band(ratio, 0.28, 0.62);
      n++;
    }
    // ووزن الخطّ يشدّ التسلسل أو ينقضه.
    final heavier = sub == null || h.weight >= sub.weight;
    score += heavier ? 1 : 0.3;
    n++;

    return n == 0 ? 0.5 : score / n;
  }

  /// **الاصطفاف**: كم حافّة مختلفة في التصميم؟
  ///
  /// أظهر فرق بين تصميمٍ مصمَّم وآخر مركَّب هو الحواف: المصمّم يصفّ
  /// عناصره على محاور قليلة، والمركِّب يترك كل عنصر حيث وقع. فنعدّ
  /// الحواف المتمايزة (بداية ونهاية ومنتصف) ونكافئ القلّة.
  static double _alignment(DesignSpec s) {
    final visible = _live(s).where((e) => e.rect.w > 0.02).toList();
    if (visible.length < 2) return 1;

    double edgeScore(Iterable<double> values) {
      final distinct = <double>[];
      for (final v in values) {
        if (!distinct.any((d) => (d - v).abs() <= _edgeTolerance)) {
          distinct.add(v);
        }
      }
      // محورٌ واحد مثالي، وعددٌ بعدد العناصر أسوأ حال.
      final worst = values.length.toDouble();
      return 1 - ((distinct.length - 1) / math.max(1, worst - 1));
    }

    final starts = visible.map((e) => e.rect.x);
    final ends = visible.map((e) => e.rect.right);
    final centres = visible.map((e) => e.rect.x + e.rect.w / 2);

    // الأفضل من الثلاثة: تصميمٌ يصطفّ على المنتصف لا يُعاقَب لأن بداياته
    // مختلفة — وهو تكوين مركزي مشروع.
    return [
      edgeScore(starts),
      edgeScore(ends),
      edgeScore(centres),
    ].reduce(math.max);
  }

  /// **التوازن**: أين ثقل الحبر؟
  ///
  /// لا نطلب مركزًا تامًّا — التكوين غير المركزي أجمل، وقِستُ في بنر
  /// كانفا حقيقي منتجًا عند ٤٢٪ لا ٥٠٪. نطلب ألّا يتكدّس الثقل في ركن
  /// وتبقى ثلاثة أرباع اللوحة خاوية.
  static double _balance(DesignSpec s) {
    var mx = 0.0, my = 0.0, mass = 0.0;
    for (final e in _live(s)) {
      final a = e.rect.w * e.rect.h * _visualWeight(e);
      if (a <= 0) continue;
      mx += (e.rect.x + e.rect.w / 2) * a;
      my += (e.rect.y + e.rect.h / 2) * a;
      mass += a;
    }
    if (mass <= 0) return 0;
    final dx = (mx / mass) - 0.5;
    final dy = (my / mass) - 0.5;
    final dist = math.sqrt(dx * dx + dy * dy);
    // ٠٫٠٨ انحراف مقبول تمامًا، و٠٫٣٠ فأكثر ركنٌ مائل.
    return 1 - ((dist - 0.08) / 0.22).clamp(0.0, 1.0);
  }

  /// **الفراغ**: لا مزدحم ولا خاوٍ — بالتغطية الحقيقية لا بمجموع الصناديق.
  ///
  /// كان الحساب `covered += w * h` — مجموعًا لا اتّحادًا. فثمانية ألواح
  /// فوق بعضها بالضبط تُشبع البند بلا بكسل جديد واحد: تصميمٌ محتواه كلّه
  /// محشور في خيط ارتفاعه ٦٪ من اللوحة كان يأخذ ١٫٠٠ كاملة.
  ///
  /// والقياس الآن بشبكة عيّنات ٤٠×٤٠: تقريبٌ كافٍ ورخيص (١٦٠٠ فحص لكل
  /// مرشَّح)، ويقول الحقيقة التي يقولها البصر.
  ///
  /// والمنتج الذي يملأ اللوحة يُستثنى: هو **خلفية** المشهد لا ازدحامًا
  /// فيه، وحسابُه ضمن التغطية كان يُسقط تصميمًا سليمًا تمامًا (صورة ملء
  /// الإطار ولوح داكن أسفلها) إلى ٦٤ درجة.
  static double _whitespace(DesignSpec s) {
    final live = _live(s)
        .where((e) => !(e.role == ElementRole.product && _isBackdrop(e)))
        .toList();
    if (live.isEmpty) return 0;

    const n = 40;
    var hit = 0;
    for (var i = 0; i < n; i++) {
      final x = (i + 0.5) / n;
      for (var j = 0; j < n; j++) {
        final y = (j + 0.5) / n;
        for (final e in live) {
          if (x >= e.rect.x &&
              x < e.rect.right &&
              y >= e.rect.y &&
              y < e.rect.bottom) {
            hit++;
            break;
          }
        }
      }
    }
    return _band(hit / (n * n), 0.28, 0.72);
  }

  /// عنصرٌ يكاد يملأ اللوحة — خلفية لا محتوى.
  static bool _isBackdrop(DesignElement e) =>
      e.rect.w >= 0.85 && e.rect.h >= 0.85;

  /// **ملاءمة الصيغة**: التكوين يتبع اللوحة لا العكس.
  ///
  /// لوحةٌ عريضة (كرت، بنر) تُقرأ أفقيًّا: النصّ في جهة والمنتج في
  /// الأخرى. وكدسُ العناصر عموديًّا في كرت ‎9×5‎ يعطي شرائح مضغوطة لا
  /// تصميمًا. والعكس في الرول أب الطويل.
  static double _formatFit(DesignSpec s) {
    final product = s.firstOf(ElementRole.product);
    final head = s.firstOf(ElementRole.headline);
    if (product == null || head == null) return 0.7;

    final sideBySide =
        (product.rect.x >= head.rect.right - 0.02) ||
        (head.rect.x >= product.rect.right - 0.02);
    final stacked =
        (product.rect.y >= head.rect.bottom - 0.02) ||
        (head.rect.y >= product.rect.bottom - 0.02);

    return switch (s.format.aspectClass) {
      AspectClass.wide => sideBySide ? 1.0 : (stacked ? 0.25 : 0.5),
      AspectClass.tall => stacked ? 1.0 : (sideBySide ? 0.35 : 0.6),
      _ => sideBySide || stacked ? 0.9 : 0.6,
    };
  }

  /// **الإيقاع**: تساوي الفجوات الرأسية بين الكتل.
  ///
  /// فجوةٌ ٢٪ ثم ٩٪ ثم ٣٪ تبدو صدفة. والمصمّم يستعمل مقياسًا واحدًا
  /// ومضاعفاته — فنقيس تشتّت الفجوات لا مقدارها.
  static double _rhythm(DesignSpec s) {
    final blocks = _live(s).where((e) => e.rect.h > 0.02).toList()
      ..sort((a, b) => a.rect.y.compareTo(b.rect.y));
    if (blocks.length < 3) return 1;

    // الفجوات السالبة **تُعاقَب** لا تُحذَف.
    //
    // كانت `if (g >= 0)` تُسقطها من العيّنة، فكلّ زوج متراكب يختفي من
    // الحساب. وأثر ذلك مقلوب تمامًا: توسيعُ كتلةٍ حتى تبتلع تاليتيها
    // رفع الدرجة من ٧٣ إلى ٩٢ — البند الذي يُعاقب الفوضى كافأها.
    final gaps = <double>[];
    var overlaps = 0;
    for (var i = 1; i < blocks.length; i++) {
      final g = blocks[i].rect.y - blocks[i - 1].rect.bottom;
      if (g < 0) {
        overlaps++;
      } else {
        gaps.add(g);
      }
    }
    final penalty = 1 - (overlaps / (blocks.length - 1)).clamp(0.0, 1.0);
    if (gaps.length < 2) return penalty * 0.5;

    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    if (mean <= 0) return penalty * 0.6;
    var variance = 0.0;
    for (final g in gaps) {
      variance += (g - mean) * (g - mean);
    }
    final cv = math.sqrt(variance / gaps.length) / mean;
    // معامل اختلاف تحت ٠٫٤ إيقاعٌ منتظم، وفوق ١٫٢ فوضى.
    return penalty * (1 - ((cv - 0.4) / 0.8).clamp(0.0, 1.0));
  }

  /// **البؤرة**: عنصرٌ واحد يسيطر.
  ///
  /// إعلانٌ كل عناصره بالحجم نفسه لا بؤرة له، والعين لا تعرف أين تقع.
  /// نقيس نسبة أكبر عنصر إلى مجموع المساحات.
  static double _focus(DesignSpec s, ArtPalette art) {
    final live = _live(s);
    if (live.isEmpty) return 0;
    var largest = 0.0, sum = 0.0;
    for (final e in live) {
      final a = e.rect.w * e.rect.h;
      sum += a;
      if (a > largest) largest = a;
    }
    if (sum <= 0) return 0;
    // بين ٣٠٪ و٦٥٪ من مجموع المساحة: بؤرة واضحة بلا ابتلاع البقيّة.
    return _band(largest / sum, 0.30, 0.65);
  }

  /// **السلامة**: كم أصلح الطبيب؟
  ///
  /// الدرجة تُحسب على المواصفة **بعد** الإصلاح — وهذا صحيح لأنه ما
  /// يُرسم فعلًا. لكنه يفتح بابًا مقلوبًا: تخطيطٌ فوضويّ يُصلحه الطبيب
  /// بإزاحاتٍ منتظمة قد يخرج أنظف إيقاعًا من تخطيطٍ كان سليمًا أصلًا،
  /// فيتقدّم عليه. وقياسًا: توسيعُ كتلةٍ حتى تبتلع تاليتيها رفع الدرجة
  /// من ٧٢ إلى ٨٩.
  ///
  /// فالإصلاح يُخصَم: «لم يحتج تصحيحًا» إشارةُ جودةٍ حقيقية، ومصمّمٌ
  /// أصاب من أوّل مرّة أولى ممّن أصابه المدقّق.
  static double _intact(SpecReport report) {
    final repaired = report.issues.where((i) => i.repaired).length;
    return (1 - repaired / 3).clamp(0.0, 1.0);
  }

  /// وزن العنصر البصري: المنتج والألواح تثقل، والنصّ الخفيف يخفّ.
  static double _visualWeight(DesignElement e) => switch (e.role) {
    ElementRole.product => 1.0,
    ElementRole.logo => 0.8,
    ElementRole.shape => e.fill != null ? 0.7 : 0.15,
    ElementRole.headline => 0.9,
    _ => 0.55,
  };

  /// درجة «داخل المجال»: ١ داخله، وتتناقص خطّيًّا خارجه.
  static double _band(double v, double lo, double hi) {
    if (v >= lo && v <= hi) return 1;
    final span = (hi - lo).abs();
    if (span <= 0) return 0;
    final off = v < lo ? lo - v : v - hi;
    return (1 - off / span).clamp(0.0, 1.0);
  }
}
