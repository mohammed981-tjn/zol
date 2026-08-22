import 'package:flutter/material.dart';
import '../models/ad_template.dart';
import '../models/ad_format.dart';
import '../models/generated_ad.dart';
import '../models/print_catalog.dart';
import 'ad_design_preview.dart';

/// معاينة التصميم على المطبوع الفعلي قبل الشراء — نمط
/// VistaPrint / Printify: العميل يرى بنره أو استيكراته أو كرته كما ستصله،
/// فيقلّ التردّد وتقلّ الطلبات الخاطئة والمرتجعات.
///
/// كل شيء مرسوم على الجهاز من التصميم نفسه — لا صور مجسّمات جاهزة.
class PrintMockupPreview extends StatelessWidget {
  const PrintMockupPreview({
    super.key,
    required this.ad,
    required this.template,
    required this.mockup,
    required this.sizeLabel,
  });

  final GeneratedAd ad;
  final AdTemplate template;
  final PrintMockup mockup;
  final String sizeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        // خلفية «استوديو» محايدة تُبرز المطبوع.
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEDEBE8), Color(0xFFD9D5D0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: switch (mockup) {
                PrintMockup.banner => _Banner(design: _design),
                PrintMockup.stickers => _Stickers(design: _design),
                PrintMockup.card => _BusinessCards(design: _design),
                PrintMockup.rollup => _RollUp(design: _design),
                PrintMockup.flyer => _Flyer(design: _design),
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'معاينة تقريبية • $sizeLabel',
                style: const TextStyle(color: Colors.white, fontSize: 10.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// التصميم مقصوصًا ليملأ أي مساحة يُطلب منه ملؤها.
  Widget get _design => _FittedDesign(ad: ad, template: template);
}

/// يملأ الحيّز المتاح بالتصميم مع الحفاظ على تناسبه (قصّ ما يزيد).
class _FittedDesign extends StatelessWidget {
  const _FittedDesign({required this.ad, required this.template});

  final GeneratedAd ad;
  final AdTemplate template;

  @override
  Widget build(BuildContext context) {
    // النسبة من الصيغة نفسها لا من مقارنة نصّية بقيمتين.
    //
    // كانت `format == 'منشور مربع' ? 1.0 : 9/16`: كل ما ليس مربّعًا
    // يُرسم ٩:١٦. فيوافق التاجر على رول أب ‎85×200‎ رآه بنسبة الستوري،
    // وعلى كرت ‎9×5‎ رآه طوليًّا — ثم يأتيه المطبوع على غير ما رأى. وهي
    // أيضًا مقارنة بنصّ عربي محفور تنكسر بأول ترجمة.
    final ratio = adFormatFromLabel(ad.brief.format).aspect;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 400,
        height: 400 / ratio,
        child: AdDesignPreview(
          ad: ad,
          template: template,
          showWatermark: false,
        ),
      ),
    );
  }
}

// ── بنر معلّق بعيون تثبيت ──────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({required this.design});
  final Widget design;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: Stack(
        children: [
          // Positioned.fill ضروري: أبناء Stack غير المموضعين يتلقّون قيودًا
          // مرنة، فيتقلّص التصميم إلى مربّع بدل أن يملأ عرض البنر.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: design,
            ),
          ),
          // عيون التثبيت في الزوايا الأربع.
          for (final alignment in [
            Alignment.topLeft,
            Alignment.topRight,
            Alignment.bottomLeft,
            Alignment.bottomRight,
          ])
            Align(
              alignment: alignment,
              child: Container(
                margin: const EdgeInsets.all(7),
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFF9AA0A6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── ورقة استيكرات مقصوصة ──────────────────────────────────────────────

class _Stickers extends StatelessWidget {
  const _Stickers({required this.design});
  final Widget design;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: List.generate(
          6,
          (_) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              // خط القصّ المتقطّع الذي يميّز ورقة الاستيكرات.
              border: Border.all(color: const Color(0xFFB9BDC2), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: design,
          ),
        ),
      ),
    );
  }
}

// ── كرتا أعمال متداخلتان ──────────────────────────────────────────────

class _BusinessCards extends StatelessWidget {
  const _BusinessCards({required this.design});
  final Widget design;

  @override
  Widget build(BuildContext context) {
    Widget card({required double rotation, required Offset offset}) {
      return Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: rotation,
          child: AspectRatio(
            aspectRatio: 9 / 5,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: design,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          card(rotation: -0.14, offset: const Offset(-18, 14)),
          card(rotation: 0.05, offset: const Offset(16, -10)),
        ],
      ),
    );
  }
}

// ── ستاند رول أب بقاعدة ───────────────────────────────────────────────

class _RollUp extends StatelessWidget {
  const _RollUp({required this.design});
  final Widget design;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 0.42,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: design,
            ),
          ),
        ),
        // قاعدة الستاند المعدنية.
        Container(
          width: 96,
          height: 9,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8E949B), Color(0xFFC7CCD1), Color(0xFF8E949B)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// معاينة الفلاير: ورقتان متداخلتان بميل خفيف — كما تُعرض حزمة فلايرات
/// على طاولة، لا ورقة واحدة معلّقة في الفراغ.
class _Flyer extends StatelessWidget {
  const _Flyer({required this.design});
  final Widget design;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // ‎A5‎ بنسبته الحقيقية، هي نفسها التي يرسم بها محرّك التصميم.
      aspectRatio: 148 / 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.07,
            child: FractionallySizedBox(
              widthFactor: 0.94,
              heightFactor: 0.94,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: design,
            ),
          ),
        ],
      ),
    );
  }
}
