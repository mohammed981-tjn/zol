import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/ad_template.dart';
import '../models/generated_ad.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// محرك قوالب التصميم — الطبقة الأولى من استراتيجية الذكاء (على الجهاز
/// 100%): يركّب صورة المنتج مع النص والهوية على أحد ستة قوالب مختلفة
/// التركيب، بلوحة ألوان مشتقّة من العلامة أو من صورة المنتج نفسها.
///
/// كل المقاسات مضروبة في عامل [_Spec.s] المشتق من عرض اللوحة، فيبدو
/// التصميم متطابقًا في المعاينة الصغيرة وفي التصدير عالي الدقة.
class AdDesignPreview extends StatelessWidget {
  const AdDesignPreview({
    super.key,
    required this.ad,
    this.template = AdTemplate.bold,
    this.showWatermark = true,
  });

  final GeneratedAd ad;
  final AdTemplate template;

  /// علامة الخطة المجانية المائية (تُزال في الخطة الاحترافية).
  final bool showWatermark;

  /// نسبة العرض إلى الارتفاع حسب صيغة الإعلان.
  double get aspectRatio => switch (ad.brief.format) {
    'منشور مربع' => 1,
    'ستوري' => 9 / 16,
    _ => 9 / 16,
  };

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final palette = AdPalette.resolve(
      brandColor: state.brandColorValue,
      productColor: ad.brief.paletteColor,
      tone: ad.brief.tone,
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spec = _Spec(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            palette: palette,
            ad: ad,
            logo: state.brandLogoBytes,
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(18 * spec.s),
            child: Stack(
              fit: StackFit.expand,
              children: [
                switch (template) {
                  AdTemplate.bold => _BoldLayout(spec: spec),
                  AdTemplate.split => _SplitLayout(spec: spec),
                  AdTemplate.poster => _PosterLayout(spec: spec),
                  AdTemplate.spotlight => _SpotlightLayout(spec: spec),
                  AdTemplate.minimal => _MinimalLayout(spec: spec),
                  AdTemplate.offer => _OfferLayout(spec: spec),
                },
                if (spec.logo != null)
                  Positioned(
                    top: 12 * spec.s,
                    left: 12 * spec.s,
                    child: _BrandLogo(spec: spec),
                  ),
                if (showWatermark)
                  Positioned(
                    bottom: 8 * spec.s,
                    left: 12 * spec.s,
                    child: Text(
                      'zol ✦',
                      style: TextStyle(
                        color: (template.isLightSurface
                                ? Colors.black
                                : Colors.white)
                            .withValues(alpha: 0.42),
                        fontSize: 10 * spec.s,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// مواصفات الرسم المشتركة بين القوالب.
class _Spec {
  _Spec({
    required this.width,
    required this.height,
    required this.palette,
    required this.ad,
    required this.logo,
  });

  final double width;
  final double height;
  final AdPalette palette;
  final GeneratedAd ad;
  final Uint8List? logo;

  /// عامل القياس: التصميم مرسوم لعرض 400 نقطة.
  double get s => width / 400;

  Uint8List? get image => ad.brief.imageBytes;
  String get headline => ad.headline;
  String get productName => ad.brief.productName;
  List<String> get hashtags => ad.hashtags;

  /// سطح فاتح مشتق من لوحة الألوان يُوضع خلف المنتج.
  ///
  /// ضروري لأن اللوحة تُشتق من صورة المنتج نفسه، فلولا هذا التباين لذاب
  /// المنتج في خلفية بلونه (قهوة بنية على خلفية بنية مثلًا).
  Color get productBackdrop =>
      Color.lerp(palette.primary, Colors.white, 0.88)!;

  Widget product({BoxFit fit = BoxFit.contain}) {
    final bytes = image;
    if (bytes == null) {
      return Center(
        child: Icon(
          Icons.photo_outlined,
          size: 48 * s,
          color: Colors.grey.shade400,
        ),
      );
    }
    return Image.memory(bytes, fit: fit);
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40 * spec.s,
      height: 40 * spec.s,
      padding: EdgeInsets.all(4 * spec.s),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.memory(spec.logo!, fit: BoxFit.contain),
    );
  }
}

/// زر الحث على الإجراء المشترك.
class _Cta extends StatelessWidget {
  const _Cta({
    required this.spec,
    this.background = AppColors.gold,
    this.foreground = const Color(0xFF1A1A2E),
    this.outlined = false,
  });

  final _Spec spec;
  final Color background;
  final Color foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * spec.s,
        vertical: 8 * spec.s,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : background,
        border: outlined ? Border.all(color: foreground, width: 1.4 * spec.s) : null,
        borderRadius: BorderRadius.circular(22 * spec.s),
      ),
      child: Text(
        'اطلب الآن',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.bold,
          fontSize: 13 * spec.s,
        ),
      ),
    );
  }
}

Widget _hashtagLine(_Spec spec, Color color) => Text(
  spec.hashtags.take(3).join('  '),
  textAlign: TextAlign.center,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11.5 * spec.s),
);

// ── 1. جريء ──────────────────────────────────────────────────────────

class _BoldLayout extends StatelessWidget {
  const _BoldLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final on = spec.palette.onPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: spec.palette.gradient),
      child: Stack(
        children: [
          Positioned(
            top: -40 * s,
            left: -40 * s,
            child: _circle(140 * s, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -30 * s,
            right: -30 * s,
            child: _circle(110 * s, Colors.white.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: EdgeInsets.all(18 * s),
            child: Column(
              children: [
                SizedBox(height: 8 * s),
                Text(
                  spec.headline,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: on,
                    fontWeight: FontWeight.bold,
                    fontSize: 21 * s,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 14 * s),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14 * s,
                          offset: Offset(0, 6 * s),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: spec.product(fit: BoxFit.cover),
                  ),
                ),
                SizedBox(height: 14 * s),
                Text(
                  spec.productName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: on,
                    fontWeight: FontWeight.bold,
                    fontSize: 17 * s,
                  ),
                ),
                SizedBox(height: 6 * s),
                _hashtagLine(spec, on),
                SizedBox(height: 8 * s),
                _Cta(spec: spec),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. منقسم ─────────────────────────────────────────────────────────

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final on = spec.palette.onPrimary;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: spec.palette.accent),
        // مثلث قطري بلون العلامة الأساسي.
        ClipPath(
          clipper: _DiagonalClipper(),
          child: ColoredBox(color: spec.palette.primary),
        ),
        Padding(
          padding: EdgeInsets.all(20 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8 * s),
                  child: Container(
                    decoration: BoxDecoration(
                      color: spec.productBackdrop,
                      borderRadius: BorderRadius.circular(16 * s),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12 * s,
                          offset: Offset(0, 5 * s),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(12 * s),
                    child: spec.product(),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46 * s,
                      height: 4 * s,
                      color: AppColors.gold,
                    ),
                    SizedBox(height: 12 * s),
                    Text(
                      spec.headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: on,
                        fontWeight: FontWeight.bold,
                        fontSize: 20 * s,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    Text(
                      spec.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: on.withValues(alpha: 0.82),
                        fontSize: 14.5 * s,
                      ),
                    ),
                    SizedBox(height: 14 * s),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _Cta(spec: spec),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height * 0.56)
    ..lineTo(0, size.height * 0.72)
    ..close();

  @override
  bool shouldReclip(_DiagonalClipper oldClipper) => false;
}

// ── 3. ملصق ──────────────────────────────────────────────────────────

class _PosterLayout extends StatelessWidget {
  const _PosterLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    return Stack(
      fit: StackFit.expand,
      children: [
        // سطح فاتح خلف الصورة: يظهر حين تكون الصورة معزولة الخلفية،
        // فلا يبتلع لونُ القالب المنتجَ المقتطَع.
        ColoredBox(color: spec.productBackdrop),
        spec.product(fit: BoxFit.cover),
        // طبقة تعتيم سفلية تضمن قراءة النص فوق أي صورة.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.88),
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
              ],
              stops: const [0, 0.45, 0.75],
            ),
          ),
        ),
        // إطار رفيع بلون العلامة.
        Padding(
          padding: EdgeInsets.all(10 * s),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: spec.palette.primary.withValues(alpha: 0.9),
                width: 2.5 * s,
              ),
              borderRadius: BorderRadius.circular(10 * s),
            ),
          ),
        ),
        Positioned(
          left: 24 * s,
          right: 24 * s,
          bottom: 22 * s,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spec.headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20 * s,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 6 * s),
              Text(
                spec.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * s,
                ),
              ),
              SizedBox(height: 12 * s),
              _Cta(
                spec: spec,
                background: spec.palette.primary,
                foreground: spec.palette.onPrimary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 4. بقعة ضوء ──────────────────────────────────────────────────────

class _SpotlightLayout extends StatelessWidget {
  const _SpotlightLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF0E1120)),
        // هالة إشعاعية بلون العلامة خلف المنتج.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.15),
              radius: 0.85,
              colors: [
                spec.palette.primary.withValues(alpha: 0.55),
                spec.palette.primary.withValues(alpha: 0.12),
                Colors.transparent,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(22 * s),
          child: Column(
            children: [
              Expanded(flex: 6, child: spec.product()),
              SizedBox(height: 12 * s),
              Text(
                spec.productName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20 * s,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                spec.headline,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13 * s,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 14 * s),
              _Cta(
                spec: spec,
                outlined: true,
                foreground: AppColors.gold,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 5. أنيق ──────────────────────────────────────────────────────────

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    const ink = Color(0xFF1A1A2E);
    return ColoredBox(
      color: const Color(0xFFF7F5F2),
      child: Padding(
        padding: EdgeInsets.all(22 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(width: 34 * s, height: 3 * s, color: spec.palette.primary),
            SizedBox(height: 14 * s),
            Text(
              spec.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 17 * s,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 12 * s),
            Expanded(child: spec.product()),
            SizedBox(height: 12 * s),
            Text(
              spec.headline,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ink.withValues(alpha: 0.7),
                fontSize: 13.5 * s,
                height: 1.45,
              ),
            ),
            SizedBox(height: 12 * s),
            _Cta(
              spec: spec,
              background: spec.palette.primary,
              foreground: spec.palette.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 6. عرض خاص ───────────────────────────────────────────────────────

class _OfferLayout extends StatelessWidget {
  const _OfferLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final on = spec.palette.onPrimary;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: spec.palette.gradient)),
        Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 18 * s),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(200 * s),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: spec.product(fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 14 * s),
              Text(
                spec.productName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: on,
                  fontWeight: FontWeight.bold,
                  fontSize: 19 * s,
                ),
              ),
              SizedBox(height: 6 * s),
              Text(
                spec.headline,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: on.withValues(alpha: 0.85),
                  fontSize: 13 * s,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 10 * s),
              _Cta(spec: spec),
            ],
          ),
        ),
        // شارة العرض الدائرية.
        Positioned(
          top: 14 * s,
          right: 14 * s,
          child: Transform.rotate(
            angle: 0.22,
            child: Container(
              width: 76 * s,
              height: 76 * s,
              decoration: BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10 * s,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'عرض\nخاص',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF1A1A2E),
                  fontWeight: FontWeight.bold,
                  fontSize: 15 * s,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _circle(double size, Color color) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
);
