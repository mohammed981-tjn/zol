import 'dart:math' as math;
import 'dart:ui';

import 'art_mood.dart';

/// محرك الانسجام اللوني — الفرق بين «تصميم» و«ترتيب عناصر».
///
/// كان التصميم يُبنى على **لون واحد** مستخرج من صورة المنتج، ودرجةٍ
/// أغمق منه للتدرّج. ذلك يعطي لوحة أحادية باهتة: كل شيء بنّي حول منتج
/// بنّي. المصمّم البشري لا يفعل هذا — يأخذ لون المنتج ثم يبني حوله
/// **علاقة**: مرافقًا مكمّلًا يقابله على عجلة الألوان، وحياديًّا يريح
/// العين، وحبرًا يُقرأ فوق كليهما.
///
/// كل ما هنا حسابٌ صرف على الجهاز: لا نداء، لا حصة، ولا انتظار.
class ArtPalette {
  const ArtPalette({
    required this.base,
    required this.deep,
    required this.complement,
    required this.neutral,
    required this.ink,
    required this.onInk,
    required this.scheme,
  });

  /// لون الهوية (العلامة أو المستخرَج من المنتج).
  final Color base;

  /// درجة عميقة منه — للخلفيات والأعماق.
  final Color deep;

  /// اللون المقابل المنسجم — للشارات والتفاصيل التي يجب أن «تقفز».
  final Color complement;

  /// حياديّ دافئ/بارد مشتقّ من الأساس — للأسطح خلف المنتج والنصوص
  /// الثانوية. الحيادي الرمادي المحض يبدو ميّتًا بجانب لون حيّ.
  final Color neutral;

  /// لون النص فوق [deep]/[base] — يُختار بالتباين لا بالذوق.
  final Color ink;

  /// لون النص فوق [neutral] الفاتح.
  final Color onInk;

  /// نوع الانسجام المختار — يُعرض في الشرح ويُستعمل للتنويع.
  final HarmonyScheme scheme;

  /// يبني لوحة كاملة من لون واحد.
  ///
  /// [variant] يُنوّع الانسجام بين إعلان وآخر بلا عشوائية: نفس المنتج
  /// ونفس الرقم يعطيان نفس اللوحة دائمًا (التصميم يجب أن يكون قابلًا
  /// لإعادة الإنتاج، وإلا اختلف ما يراه التاجر عمّا يصدّره).
  factory ArtPalette.from(Color source, {int variant = 0}) {
    final hsl = _Hsl.fromColor(source);

    // لون شديد الشحوب أو شديد القتامة لا يصلح أساسًا: نرفع تشبّعه
    // ونضعه في نطاق يحتمل الاشتقاق.
    final s = hsl.s < 0.22 ? 0.42 : math.min(hsl.s, 0.92);
    final l = hsl.l.clamp(0.28, 0.62);
    final baseHsl = _Hsl(hsl.h, s, l);

    final scheme =
        HarmonyScheme.values[variant.abs() % HarmonyScheme.values.length];

    // زاوية المرافق حسب نوع الانسجام. المتماثل (180°) أقوى تباينًا،
    // والثلاثي (120°) أكثر مرحًا، والمنشقّ (150°) أهدأ وأكثر أناقة.
    final angle = switch (scheme) {
      HarmonyScheme.complementary => 180.0,
      HarmonyScheme.splitComplementary => 150.0,
      HarmonyScheme.triadic => 120.0,
      HarmonyScheme.analogous => 38.0,
    };

    final complement = _Hsl(
      (baseHsl.h + angle) % 360,
      math.min(0.95, baseHsl.s + 0.08),
      // المرافق أفتح قليلًا ليقفز فوق الخلفية العميقة.
      (baseHsl.l + 0.18).clamp(0.42, 0.74),
    ).toColor();

    final deep = _Hsl(
      baseHsl.h,
      math.min(0.9, baseHsl.s + 0.05),
      (baseHsl.l * 0.34).clamp(0.06, 0.2),
    ).toColor();

    // الحيادي يحمل درجة الأساس بتشبّع ضئيل — رمادي «ملوَّن» يبقى
    // منتميًا للوحة بدل أن يبدو دخيلًا.
    final neutral = _Hsl(baseHsl.h, 0.10, 0.94).toColor();

    return ArtPalette(
      base: baseHsl.toColor(),
      deep: deep,
      complement: complement,
      neutral: neutral,
      ink: _readableOn(deep),
      onInk: _readableOn(neutral),
      scheme: scheme,
    );
  }

  /// يبني لوحة من **مزاج مختار** بدل الاشتقاق من لون واحد.
  ///
  /// راجع `ArtMood` للسبب. والفرق عن [ArtPalette.from] أن الألوان تُؤخذ
  /// كما هي ولا تُحسب — فلا تشبّع يُرفع ولا إضاءة تُقصّ ولا زاوية تُدار.
  ///
  /// والحبران وحدهما يُحسبان هنا كما يُحسبان هناك: `ink` و`onInk`
  /// قراءةٌ لا ذوق، ولو اخترناهما بالعين لكسرنا التباين في مزاجٍ فاتح
  /// ظنناه داكنًا. وهذا ما يجعل إضافة مزاجٍ جديد آمنة: يكفي أن تُختار
  /// ألوانه، والقراءة يضمنها الحساب.
  ///
  /// و[scheme] هنا وصفٌ لا سبب: اللوحة لم تُبنَ على انسجام محسوب، لكن
  /// الحقل مطلوبٌ في العقد ويُعرض في الشرح. فيُنسب إلى `complementary`
  /// لأنّ كل مزاج فيها أساسٌ ومرافقٌ يقابله — وهو أصدق ما يُقال عنها.
  factory ArtPalette.fromMood(ArtMood mood) => ArtPalette(
    base: mood.base,
    deep: mood.deep,
    complement: mood.complement,
    neutral: mood.neutral,
    ink: _readableOn(mood.deep),
    onInk: _readableOn(mood.neutral),
    scheme: HarmonyScheme.complementary,
  );

  /// حبر مقروء فوق [bg] — بالقياس لا بالذوق.
  ///
  /// سُلَّم من ثلاث درجات لا خيارين. الحبر المفضّل `#141728` أرقّ من
  /// الأسود المحض ويليق بالطباعة، لكنه يسقط في شريط ضيّق من الإضاءات
  /// المتوسطة: هناك لا الأبيض يبلغ ٤٫٥ ولا هو. أضيف الأسود المحض ثالثًا
  /// لأنه يسدّ ذلك الشريط برهانًا لا بالتجربة: الأبيض يكفي عند إضاءة
  /// خلفية ≤ ٠٫١٨٣، والأسود يكفي عند ≥ ٠٫١٧٥، والمجالان متداخلان — فلا
  /// توجد خلفية يعجز عنها الاثنان معًا.
  ///
  /// وهذا يبقي لون العلامة كما اختاره التاجر: نغيّر الحبر لا هويّته.
  static Color _readableOn(Color bg) {
    const white = Color(0xFFFFFFFF);
    const soft = Color(0xFF141728);
    const black = Color(0xFF000000);
    for (final ink in [white, soft, black]) {
      if (contrast(bg, ink) >= 4.5) {
        // الأبيض يُقدَّم على الداكن حين يصلحان معًا فوق خلفية عميقة،
        // والعكس فوق خلفية فاتحة — والمقارنة أدناه تحسم ذلك.
        if (ink == white && contrast(bg, soft) > contrast(bg, white)) {
          continue;
        }
        return ink;
      }
    }
    return contrast(bg, white) >= contrast(bg, black) ? white : black;
  }

  /// نسبة التباين بين لونين (١ إلى ٢١) بمعادلة WCAG.
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// لون النص المضمون فوق أي خلفية — يُستعمل حيث تُرسم الحروف فعلًا.
  static Color inkOn(Color bg) => _readableOn(bg);

  /// درجة من الأساس بإضاءة مطلوبة — للتدرّجات والطبقات.
  Color shade(double lightness) {
    final h = _Hsl.fromColor(base);
    return _Hsl(h.h, h.s, lightness.clamp(0.0, 1.0)).toColor();
  }
}

/// أنواع الانسجام المدعومة — أسماؤها العربية تظهر للتاجر في الشرح.
enum HarmonyScheme { complementary, splitComplementary, triadic, analogous }

extension HarmonySchemeInfo on HarmonyScheme {
  String get label => switch (this) {
    HarmonyScheme.complementary => 'تباين متقابل',
    HarmonyScheme.splitComplementary => 'تباين منشقّ',
    HarmonyScheme.triadic => 'ثلاثي',
    HarmonyScheme.analogous => 'متجاور',
  };
}

/// تمثيل HSL خفيف — Flutter يوفّر HSLColor لكنه يجرّ اعتماديات الرسم
/// إلى الاختبارات الخالصة، وهذا الحساب بسيط ومكشوف.
class _Hsl {
  const _Hsl(this.h, this.s, this.l);

  final double h; // 0..360
  final double s; // 0..1
  final double l; // 0..1

  factory _Hsl.fromColor(Color c) {
    final r = (c.r * 255).round() / 255;
    final g = (c.g * 255).round() / 255;
    final b = (c.b * 255).round() / 255;
    final maxC = math.max(r, math.max(g, b));
    final minC = math.min(r, math.min(g, b));
    final l = (maxC + minC) / 2;
    final d = maxC - minC;
    if (d == 0) return _Hsl(0, 0, l);
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
    return _Hsl(h, s, l);
  }

  Color toColor() {
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
    return Color.fromARGB(255, ch(r), ch(g), ch(b));
  }
}
