import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/art_palette.dart';

/// خلفيات فنية مرسومة على الجهاز — بديل التدرّج الخطّي المسطّح الذي
/// كان يملأ كل قالب فيجعل التصاميم العشرة تبدو تصميمًا واحدًا.
///
/// ثلاث طبقات تُبنى فوق بعضها كما يفعل المصمّم:
///   ١) تدرّج شبكي: بؤر لونية ناعمة متداخلة تعطي عمقًا لا يعطيه خطّ
///      واحد من لون إلى لون.
///   ٢) أشكال هندسية خافتة: أقواس ودوائر تكسر الفراغ وتوجّه العين.
///   ٣) حبيبات: ضجيج خفيف جدًا يمنع «البلاستيكية» الرقمية — الحيلة
///      التي تجعل الخلفية تبدو مطبوعة لا مولَّدة.
///
/// كل شيء حتميّ: نفس [seed] يعطي نفس الخلفية دائمًا، فما يراه التاجر
/// في المعاينة هو ما يُصدَّر بالضبط.
class ArtBackdrop extends StatelessWidget {
  const ArtBackdrop({
    super.key,
    required this.palette,
    this.seed = 0,
    this.style = BackdropStyle.mesh,
    this.grain = true,
  });

  final ArtPalette palette;
  final int seed;
  final BackdropStyle style;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackdropPainter(
        palette: palette,
        seed: seed,
        style: style,
        grain: grain,
      ),
      isComplex: true,
      willChange: false,
      child: const SizedBox.expand(),
    );
  }
}

enum BackdropStyle {
  /// بؤر لونية متداخلة — الأغنى، للقوالب الجريئة.
  mesh,

  /// إضاءة مسرح: هالة واحدة من الأعلى وظلام يتدرّج للأسفل.
  spotlight,

  /// أقواس متراكزة تخرج من زاوية — إحساس حركة وانطلاق.
  arcs,

  /// طبقات قماشية مائلة — هادئ وأنيق للمنتجات الفاخرة.
  strata,

  /// ورق فاتح: أرضية حيادية دافئة وبقع لونية شديدة الخفوت وحبيبات.
  ///
  /// القوالب الفاتحة (الأنيق، رأي عميل، الإطار، الدائري) كانت تُملأ بلون
  /// مسطّح واحد `#F7F5F2` لا علاقة له بهوية التاجر. هذا النمط يبقيها
  /// فاتحةً متنفّسة لكن يجعلها **ورقًا مطبوعًا بلون العلامة** لا فراغًا.
  paper,
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.palette,
    required this.seed,
    required this.style,
    required this.grain,
  });

  final ArtPalette palette;
  final int seed;
  final BackdropStyle style;
  final bool grain;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = math.Random(seed * 7919 + style.index);

    // الأرضية: عميقة تحت الأنماط الداكنة (الطبقات فوقها تُضيء لا تُظلم)،
    // وحيادية فاتحة تحت نمط الورق.
    canvas.drawRect(
      rect,
      Paint()
        ..color = style == BackdropStyle.paper ? palette.neutral : palette.deep,
    );

    switch (style) {
      case BackdropStyle.mesh:
        _paintMesh(canvas, size, rnd);
      case BackdropStyle.spotlight:
        _paintSpotlight(canvas, size);
      case BackdropStyle.arcs:
        _paintArcs(canvas, size, rnd);
      case BackdropStyle.strata:
        _paintStrata(canvas, size);
      case BackdropStyle.paper:
        _paintPaper(canvas, size, rnd);
    }

    if (grain) _paintGrain(canvas, size, rnd);
  }

  /// بؤر شعاعية متداخلة. ثلاث بؤر تكفي: الرابعة تُوحل اللوحة.
  ///
  /// الشفافيات غير متساوية عمدًا. البؤرة المرافقة **لمسة** لا نصف
  /// اللوحة: عند التساوي يمتزج اللونان المتقابلان (أحمر فوق أخضر مثلًا)
  /// فيخرج زيتوني موحل — وهو أشهر خطأ يقع فيه من يستعمل التقابل اللوني
  /// أول مرة.
  void _paintMesh(Canvas canvas, Size size, math.Random rnd) {
    final blobs = <(Offset, double, Color, double)>[
      (
        Offset(size.width * (0.18 + rnd.nextDouble() * 0.2),
            size.height * (0.14 + rnd.nextDouble() * 0.12)),
        size.width * 0.95,
        palette.base,
        0.64,
      ),
      (
        Offset(size.width * (0.72 + rnd.nextDouble() * 0.18),
            size.height * (0.3 + rnd.nextDouble() * 0.15)),
        size.width * 0.62,
        palette.complement,
        0.3,
      ),
      (
        Offset(size.width * 0.45, size.height * (0.88 + rnd.nextDouble() * 0.08)),
        size.width * 0.9,
        palette.shade(0.34),
        0.58,
      ),
    ];

    for (final (center, radius, color, alpha) in blobs) {
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0.0),
        ], const [0.0, 1.0]);
      canvas.drawCircle(center, radius, paint);
    }
  }

  void _paintSpotlight(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.34);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(center, size.width * 0.85, [
          palette.base.withValues(alpha: 0.75),
          palette.deep.withValues(alpha: 0.0),
        ], const [0.0, 1.0]),
    );
    // قاع أعمق يثبّت الزرّ والنص السفلي على أرض صلبة.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, size.height * 0.55),
          Offset(0, size.height),
          [palette.deep.withValues(alpha: 0.0), palette.deep],
        ),
    );
  }

  void _paintArcs(Canvas canvas, Size size, math.Random rnd) {
    final origin = Offset(size.width * 1.02, size.height * 0.12);
    for (var i = 6; i >= 1; i--) {
      final r = size.width * (0.22 * i);
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.012
          ..color = (i.isEven ? palette.base : palette.complement)
              .withValues(alpha: 0.16 + rnd.nextDouble() * 0.06),
      );
    }
    canvas.drawCircle(
      origin,
      size.width * 0.3,
      Paint()
        ..shader = ui.Gradient.radial(origin, size.width * 0.3, [
          palette.complement.withValues(alpha: 0.5),
          palette.complement.withValues(alpha: 0.0),
        ]),
    );
  }

  void _paintStrata(Canvas canvas, Size size) {
    // المرافق في الطبقة الأخيرة لمسة رفيعة (٠٫١٢) لا صبغة: عند ٠٫٢٨ كان
    // يمتزج بالأساس المقابل فيخرج بنّي موحل في أسفل التصميم — وهو
    // بالضبط ما ظهر في القالب المشقوق قبل هذا الضبط.
    final layers = [
      (0.38, palette.base.withValues(alpha: 0.55)),
      (0.56, palette.shade(0.26).withValues(alpha: 0.8)),
      (0.74, palette.complement.withValues(alpha: 0.12)),
    ];
    for (final (start, color) in layers) {
      final path = Path()
        ..moveTo(0, size.height * start)
        ..lineTo(size.width, size.height * (start - 0.12))
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
  }

  /// ورق: بقعتان بالغتا الخفوت في زاويتين متقابلتين، وحافة خارجية أدكن
  /// بقليل (vignette) تمنع الإحساس بأن الإطار «مقصوص من صفحة بيضاء».
  ///
  /// شفافية ٠٫١٠ ليست تردّدًا: القالب الفاتح يبيع بالفراغ، وأي لون أقوى
  /// من ذلك يحوّل الورق إلى خلفية ملوّنة ويهدم سبب وجود القالب.
  void _paintPaper(Canvas canvas, Size size, math.Random rnd) {
    final blobs = <(Offset, double, Color)>[
      (
        Offset(size.width * 0.12, size.height * 0.1),
        size.width * 0.8,
        palette.base,
      ),
      (
        Offset(size.width * 0.92, size.height * 0.86),
        size.width * 0.72,
        palette.complement,
      ),
    ];
    for (final (center, radius, color) in blobs) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(center, radius, [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.0),
          ], const [0.0, 1.0]),
      );
    }
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(c, size.width * 0.78, [
          const Color(0x00000000),
          Colors.black.withValues(alpha: 0.06),
        ], const [0.62, 1.0]),
    );
  }

  /// حبيبات: نقاط شبه شفافة موزّعة حتميًّا. الكثافة منخفضة عمدًا —
  /// الحبيبات تُحَسّ ولا تُرى، وزيادتها تجعل الصورة متّسخة.
  void _paintGrain(Canvas canvas, Size size, math.Random rnd) {
    final count = (size.width * size.height / 900).clamp(60, 1400).toInt();
    final light = Paint()..color = Colors.white.withValues(alpha: 0.045);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.05);
    final dot = size.width * 0.0035;
    for (var i = 0; i < count; i++) {
      final o = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawCircle(o, dot, i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.seed != seed ||
      old.style != style ||
      old.grain != grain ||
      old.palette.base != palette.base ||
      old.palette.complement != palette.complement;
}

/// مسرح المنتج: ظلّ تماسّ وهالة خلفه بدل قصاصة «ملصوقة».
///
/// أكثر ما يفضح التصميم الهاوي أن المنتج يطفو بلا ظلّ. الظلّ البيضاوي
/// تحته يثبّته على أرض، والهالة خلفه تفصله عن الخلفية بلا إطار.
class ProductStage extends StatelessWidget {
  const ProductStage({
    super.key,
    required this.child,
    required this.palette,
    this.halo = true,
    this.contactShadow = true,
    this.shadowOpacity = 0.42,
  });

  final Widget child;
  final ArtPalette palette;
  final bool halo;
  final bool contactShadow;

  /// قوّة ظلّ التماسّ. الافتراضي مضبوط للخلفيات العميقة؛ فوق الورق
  /// الفاتح يُخفَّض، وإلا بدا المنتج كأنه معلَّق فوق بقعة حبر.
  final double shadowOpacity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 300.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : 300.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (halo)
              Positioned.fill(
                child: CustomPaint(
                  painter: _HaloPainter(palette.complement),
                ),
              ),
            if (contactShadow)
              Positioned(
                left: w * 0.14,
                right: w * 0.14,
                bottom: h * 0.03,
                height: h * 0.09,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.elliptical(w, h * 0.09)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: shadowOpacity.clamp(0.0, 1.0),
                        ),
                        blurRadius: h * 0.06,
                        spreadRadius: -h * 0.01,
                      ),
                    ],
                  ),
                ),
              ),
            child,
          ],
        );
      },
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    canvas.drawCircle(
      center,
      size.width * 0.52,
      Paint()
        ..shader = ui.Gradient.radial(center, size.width * 0.52, [
          color.withValues(alpha: 0.34),
          color.withValues(alpha: 0.0),
        ]),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.color != color;
}
