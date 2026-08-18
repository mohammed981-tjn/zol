import 'package:flutter/material.dart';

import '../theme/art_palette.dart';

/// معالجة الصورة داخل التصميم — الحلقة المفقودة.
///
/// كان محرّك الفن يعالج كل شيء **حول** الصورة: الخلفية واللون والحرف.
/// أما الصورة نفسها فتُوضع خامًا كما جاءت من المعرض أو من المولّد. أثر
/// ذلك أن التصميم يبقى «قالبًا وُضعت فيه صورة» مهما جمُل ما حولها:
/// المشاهد يرى طبقتين لا لوحة — خلفية بلون العلامة، وفوقها مستطيل
/// مقتطَع من عالم آخر بإضاءته وألوانه هو.
///
/// وهذا ما يفعله المصمّم في أول دقيقة، وهو أرخص ما يُفعل وأشدّه أثرًا:
///
///   ١) **تدرّج مزدوج (split-tone)**: يُدفع ظلّ الصورة نحو عمق اللوحة
///      وضوؤها نحو مرافقها. الصورة لا تتغيّر، لكن ضوءها يصير ضوء
///      المشهد الذي وُضعت فيه — وهذا وحده يُذهب أثر القصّ واللصق.
///   ٢) **رفع تباين وتشبّع محسوب**: صور الجوّال تخرج مسطّحة، وأكثر
///      الفرق بين «صورة منتج» و«إعلان» هنا.
///   ٣) **تعتيم الأطراف (vignette)**: تغوص حواف الصورة في التصميم بدل
///      أن تنتهي بخطّ حادّ يفضح أنها ملصقة.
///
/// كله يُنفَّذ على المعالج الرسومي وقت الرسم: بلا حصة، وبلا انتظار،
/// وبلا إعادة ترميز للبكسلات.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.child,
    required this.palette,
    this.grade = 0.55,
    this.vignette = true,
    this.punch = true,
  });

  final Widget child;
  final ArtPalette palette;

  /// شدّة الدمج اللوني (٠ إلى ١). صفر يعطي الصورة كما هي.
  ///
  /// الافتراضي فوق النصف بقليل: أعلى منه يبدأ لون المنتج الحقيقي
  /// بالانحراف — وتاجرٌ يبيع قميصًا أزرق لا يقبل أن يخرج بنفسجيًّا.
  final double grade;

  final bool vignette;

  /// رفع التباين والتشبّع. يُطفأ للشعارات والرسوم المسطّحة: رفع تباين
  /// شكلٍ مصمَّم أصلًا يشوّهه ولا يحسّنه.
  final bool punch;

  @override
  Widget build(BuildContext context) {
    final g = grade.clamp(0.0, 1.0);
    Widget image = child;

    // الترتيب مقصود: التباين والتشبّع أوّلًا على البكسل الأصلي، ثم
    // الصبغ فوقهما. العكس يرفع تباين الصبغة نفسها فيُبرزها كطبقة.
    if (punch) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(_saturation(1.16)),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1.12)),
          child: image,
        ),
      );
    }

    if (g > 0) {
      // `ColorFilter.mode` لا `DecoratedBox` بنمط مزج: الثاني يمتزج بما
      // خلف الصورة أيضًا فيصبغ الخلفية والتصميم كلّه، والأول محصور
      // ببكسلات الطفل وحده — وهو المطلوب بالضبط.
      // الشدّة منخفضة عمدًا. الصبغ المتساوي على الصورة كلّها هو
      // «الثنائي اللوني» (duotone): يُوحّد الصورة بالتصميم لكنه يكذب على
      // المشتري — جرّبتُه بـ٠٫٣٤ فخرج الأخضر في الصورة أرجوانيًّا. اللون
      // الحقيقي للمنتج ليس عنصر تصميم يُتصرَّف فيه.
      //
      // الدمج الحقيقي يقع في الأطراف أدناه: هناك لا منتجَ يُكذَب عليه،
      // وهناك يقع الخطّ الحادّ الذي يفضح القصّ واللصق.
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          palette.complement.withValues(alpha: 0.15 * g),
          BlendMode.softLight,
        ),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            palette.deep.withValues(alpha: 0.12 * g),
            BlendMode.multiply,
          ),
          child: image,
        ),
      );
    }

    if (!vignette) return image;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        image,
        // التعتيم بلون العمق لا بأسود: الأسود يقرأ كظلّ غريب فوق صورة
        // ملوّنة، ولون اللوحة يقرأ كإضاءة المشهد.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.92,
                  colors: [
                    palette.deep.withValues(alpha: 0.0),
                    palette.deep.withValues(alpha: 0.22),
                    palette.deep.withValues(alpha: 0.62),
                  ],
                  stops: const [0.42, 0.74, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// مصفوفة تشبّع قياسية بأوزان الإضاءة المعتمدة (Rec. 709).
  static List<double> _saturation(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final ir = (1 - s) * lr, ig = (1 - s) * lg, ib = (1 - s) * lb;
    return [
      ir + s, ig, ib, 0, 0, //
      ir, ig + s, ib, 0, 0, //
      ir, ig, ib + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// تباين حول المنتصف: ما فوق ١٢٧٫٥ يُرفع وما دونه يُخفض.
  static List<double> _contrast(double c) {
    final t = 127.5 * (1 - c);
    return [
      c, 0, 0, 0, t, //
      0, c, 0, 0, t, //
      0, 0, c, 0, t, //
      0, 0, 0, 1, 0, //
    ];
  }
}
