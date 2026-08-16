import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/ad_badge.dart';
import '../models/ad_template.dart';
import '../models/brand_font.dart';
import '../models/generated_ad.dart';
import '../models/seasonal_theme.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// محرك قوالب التصميم — الطبقة الأولى من استراتيجية الذكاء (على الجهاز
/// 100%): يركّب صورة المنتج مع النص والهوية على أحد عشرة قوالب مختلفة
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
      seasonColor: ad.brief.season?.colorValue,
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
            fontFamily: state.brandFont?.family,
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(18 * spec.s),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(fontFamily: spec.fontFamily),
                  child: switch (template) {
                    AdTemplate.bold => _BoldLayout(spec: spec),
                    AdTemplate.split => _SplitLayout(spec: spec),
                    AdTemplate.poster => _PosterLayout(spec: spec),
                    AdTemplate.spotlight => _SpotlightLayout(spec: spec),
                    AdTemplate.minimal => _MinimalLayout(spec: spec),
                    AdTemplate.offer => _OfferLayout(spec: spec),
                    AdTemplate.testimonial => _TestimonialLayout(spec: spec),
                    AdTemplate.frame => _FrameLayout(spec: spec),
                    AdTemplate.urgency => _UrgencyLayout(spec: spec),
                    AdTemplate.circular => _CircularLayout(spec: spec),
                    AdTemplate.studio => _StudioLayout(spec: spec),
                  },
                ),
                // خلفية مصمَّمة اختيارية: زخرفة زاوية مستوحاة من النشاط
                // (نمط قوالب Canva الجاهزة) بدل التدرّج المسطّح وحده —
                // ركن صغير شفاف حتى لا يزاحم النص أو المنتج في أي قالب.
                if (ad.brief.useDecorativeBackground)
                  Positioned(
                    bottom: -28 * spec.s,
                    right: -28 * spec.s,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.16,
                        child: SvgPicture.asset(
                          'assets/backgrounds/${ad.brief.category.name}.svg',
                          width: spec.width * 0.55,
                          height: spec.width * 0.55,
                          colorFilter: ColorFilter.mode(
                            spec.palette.onPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (spec.logo != null)
                  Positioned(
                    top: 12 * spec.s,
                    left: 12 * spec.s,
                    child: _BrandLogo(spec: spec),
                  ),
                if (ad.brief.season != null)
                  Positioned(
                    top: 12 * spec.s,
                    right: 12 * spec.s,
                    child: _SeasonBadge(spec: spec, season: ad.brief.season!),
                  ),
                // الشارة الترويجية من مكتبة العناصر — تعمل فوق أي قالب،
                // وتنزل درجة حين يشغل الموسمُ ركنَها.
                if (ad.brief.badge != null)
                  Positioned(
                    top: (ad.brief.season != null ? 48 : 12) * spec.s,
                    right: 12 * spec.s,
                    child: _PromoBadge(spec: spec, badge: ad.brief.badge!),
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
    this.fontFamily,
  });

  final double width;
  final double height;
  final AdPalette palette;
  final GeneratedAd ad;
  final Uint8List? logo;

  /// خط العلامة (Brand Kit) — null يعني اعتماد خط الواجهة الافتراضي.
  final String? fontFamily;

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
    final img = Image.memory(bytes, fit: fit);
    if (!ad.brief.hasProductTransform) return img;
    // تحويل التاجر من المحرر: الإزاحة كسور من الإطار لا بكسلات، فيبقى
    // ما ضبطه في المعاينة مطابقًا له في التصدير عالي الدقة.
    return LayoutBuilder(
      builder: (context, c) => ClipRect(
        child: Transform.translate(
          offset: Offset(
            ad.brief.productDx * c.maxWidth,
            ad.brief.productDy * c.maxHeight,
          ),
          child: Transform.scale(scale: ad.brief.productScale, child: img),
        ),
      ),
    );
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

/// الشارة الترويجية من مكتبة العناصر — قطعة ملفتة بميل خفيف وظل، بلون
/// مشتق من هوية العلامة فلا تدخل لونًا غريبًا على التصميم.
class _PromoBadge extends StatelessWidget {
  const _PromoBadge({required this.spec, required this.badge});
  final _Spec spec;
  final AdBadge badge;

  @override
  Widget build(BuildContext context) {
    final bright = Color.lerp(spec.palette.primary, Colors.white, 0.62)!;
    final deep = Color.lerp(spec.palette.accent, Colors.black, 0.45)!;
    return Transform.rotate(
      angle: -0.09,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12 * spec.s,
          vertical: 6 * spec.s,
        ),
        decoration: BoxDecoration(
          color: bright,
          borderRadius: BorderRadius.circular(8 * spec.s),
          border: Border.all(color: Colors.white, width: 1.4 * spec.s),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8 * spec.s,
              offset: Offset(0, 3 * spec.s),
            ),
          ],
        ),
        child: Text(
          badge.label,
          style: TextStyle(
            color: deep,
            fontWeight: FontWeight.w900,
            fontSize: 12.5 * spec.s,
          ),
        ),
      ),
    );
  }
}

/// شارة الموسم المحلي (اليوم الوطني، رمضان، ...) — طابع احتفالي فوري
/// بلا حاجة لقالب رسومي منفصل لكل موسم.
class _SeasonBadge extends StatelessWidget {
  const _SeasonBadge({required this.spec, required this.season});
  final _Spec spec;
  final SeasonalTheme season;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * spec.s,
        vertical: 5 * spec.s,
      ),
      decoration: BoxDecoration(
        color: season.color,
        borderRadius: BorderRadius.circular(20 * spec.s),
      ),
      child: Text(
        '${season.emoji} ${season.label}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.5 * spec.s,
          fontWeight: FontWeight.bold,
        ),
      ),
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
        spec.ad.cta,
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

// ── 7. رأي عميل ──────────────────────────────────────────────────────
//
// يبيع بالثقة لا بالسعر. العنوان يُعرض كاقتباس بين علامتَي تنصيص كبيرتين،
// والنجوم تُقرأ قبل أي حرف — فتصل الرسالة قبل أن يُقرأ النص.

class _TestimonialLayout extends StatelessWidget {
  const _TestimonialLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    const ink = Color(0xFF1F2430);
    return ColoredBox(
      color: const Color(0xFFFAF8F5),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24 * s, 26 * s, 24 * s, 20 * s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.format_quote,
              size: 40 * s,
              color: spec.palette.primary.withValues(alpha: 0.35),
            ),
            SizedBox(height: 6 * s),
            Expanded(
              child: Center(
                child: Text(
                  spec.headline,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: 17 * s,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10 * s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (_) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 1.5 * s),
                  child: Icon(Icons.star_rounded,
                      size: 15 * s, color: const Color(0xFFF5A623)),
                ),
              ),
            ),
            SizedBox(height: 12 * s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 40 * s,
                    height: 40 * s,
                    child: ColoredBox(
                      color: spec.productBackdrop,
                      child: spec.product(fit: BoxFit.cover),
                    ),
                  ),
                ),
                SizedBox(width: 10 * s),
                Flexible(
                  child: Text(
                    spec.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.75),
                      fontSize: 13 * s,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14 * s),
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

// ── 8. إطار ──────────────────────────────────────────────────────────
//
// إطاران متداخلان يوحيان بالهدية والفخامة. الفراغ هنا عنصر تصميم لا نقص
// محتوى، فلا يُملأ.

class _FrameLayout extends StatelessWidget {
  const _FrameLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    const ink = Color(0xFF23201C);
    final gold = spec.palette.primary;
    return ColoredBox(
      color: const Color(0xFFFCFAF6),
      child: Padding(
        padding: EdgeInsets.all(12 * s),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.2 * s),
          ),
          child: Padding(
            padding: EdgeInsets.all(5 * s),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: gold, width: 0.8 * s),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 14 * s),
                child: Column(
                  children: [
                    Text(
                      spec.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: gold,
                        fontSize: 12 * s,
                        letterSpacing: 3 * s,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10 * s),
                    Expanded(child: spec.product()),
                    SizedBox(height: 10 * s),
                    Container(width: 46 * s, height: 1 * s, color: gold),
                    SizedBox(height: 10 * s),
                    Text(
                      spec.headline,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15 * s,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12 * s),
                    _Cta(spec: spec, background: gold,
                        foreground: spec.palette.onPrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 9. عاجل ──────────────────────────────────────────────────────────
//
// شريط قطري في الزاوية يقطع التصميم فيوقف التمرير. الحدّة مقصودة: هذا
// قالب العروض المؤقتة لا الهوية الهادئة.

class _UrgencyLayout extends StatelessWidget {
  const _UrgencyLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final accent = spec.palette.accent;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: const Color(0xFF14161C)),
        Padding(
          padding: EdgeInsets.fromLTRB(20 * s, 34 * s, 20 * s, 18 * s),
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: spec.productBackdrop,
                    borderRadius: BorderRadius.circular(10 * s),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10 * s),
                    child: spec.product(fit: BoxFit.cover),
                  ),
                ),
              ),
              SizedBox(height: 14 * s),
              Text(
                spec.headline,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19 * s,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12 * s),
              _Cta(spec: spec, background: accent, foreground: Colors.white),
            ],
          ),
        ),
        // الشريط آخر ما يُرسم ليعلو كل شيء، ومقصوص بحدود الإطار.
        Positioned.fill(
          child: ClipRect(
            child: Align(
              alignment: Alignment.topRight,
              child: Transform.translate(
                offset: Offset(38 * s, 26 * s),
                child: Transform.rotate(
                  angle: 0.785398, // ٤٥ درجة
                  child: Container(
                    width: 170 * s,
                    padding: EdgeInsets.symmetric(vertical: 5 * s),
                    color: accent,
                    child: Text(
                      'لفترة محدودة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11 * s,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2 * s,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 10. دائري ────────────────────────────────────────────────────────
//
// قرص المنتج يحتلّ المركز وحلقة تحيطه، وهو أشيع تكوين في إعلانات
// المأكولات والمشروبات: العين تستقرّ في الدائرة قبل أن تقرأ.

class _CircularLayout extends StatelessWidget {
  const _CircularLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final primary = spec.palette.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(primary, Colors.white, 0.82)!,
            Color.lerp(primary, Colors.white, 0.62)!,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20 * s, 24 * s, 20 * s, 18 * s),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: EdgeInsets.all(7 * s),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 2 * s),
                    ),
                    child: ClipOval(
                      child: ColoredBox(
                        color: Colors.white,
                        child: spec.product(fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 14 * s),
            Text(
              spec.headline,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF1A1A2E),
                fontSize: 17 * s,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10 * s),
            _Cta(
              spec: spec,
              background: primary,
              foreground: spec.palette.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 11. استوديو ──────────────────────────────────────────────────────
//
// حصيلة تشريح تصاميم Canva الحية عبر واجهتها المهيكلة (بنية العناصر
// بمواضعها وأحجامها وألوانها، لا الصور النهائية). أربعة أسرار تكوين
// تكررت في تصاميمهم ولا يملكها أي قالب عندنا:
//   ١) بطاقة داخلية بهامش ٢٪ تحيط بكل المحتوى — إطار «مُحتوى» فاخر.
//   ٢) نغمتان من عائلة اللون نفسها للهرمية: فاتحة للعنوان وكامدة
//      للسطور الثانوية — لا لون واحد يصرخ في كل شيء.
//   ٣) عنوان عملاق (~١٥٪ من العرض) بدل عناويننا الخجولة.
//   ٤) منتج غير مركزي مع عمود نص بجانبه — كل قوالبنا كانت مركزية.
class _StudioLayout extends StatelessWidget {
  const _StudioLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final p = spec.palette;
    // النغمتان: فاتحة مشرقة للعنوان، وكامدة هادئة للثانوي — من عائلة
    // العلامة نفسها فلا يدخل التصميم لون غريب.
    final bright = Color.lerp(p.primary, Colors.white, 0.62)!;
    final muted = Color.lerp(p.primary, Colors.white, 0.30)!;
    final deep = Color.lerp(p.accent, Colors.black, 0.45)!;

    return Container(
      color: deep,
      // هامش البطاقة الداخلية: ٨ من ٤٠٠ = ٢٪ كما في تشريح Canva حرفيًا.
      padding: EdgeInsets.all(8 * s),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.accent, deep],
          ),
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(
            color: bright.withValues(alpha: 0.35),
            width: 1.2 * s,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16 * s, 20 * s, 16 * s, 14 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // العنوان العملاق — يمين الصفحة (بداية القراءة العربية).
              Text(
                spec.headline,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: bright,
                  fontWeight: FontWeight.w900,
                  fontSize: 27 * s,
                  height: 1.18,
                ),
              ),
              SizedBox(height: 6 * s),
              Text(
                spec.productName,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13 * s,
                ),
              ),
              SizedBox(height: 12 * s),
              // المنتج جانبيًّا (يسار — مرآة تكوين Canva في اتجاه RTL)
              // في لوح بظل عميق، والفراغ يمينه يتنفس منه التصميم.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.78,
                    heightFactor: 0.96,
                    child: Container(
                      decoration: BoxDecoration(
                        color: spec.productBackdrop,
                        borderRadius: BorderRadius.circular(14 * s),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38),
                            blurRadius: 18 * s,
                            offset: Offset(6 * s, 10 * s),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: spec.product(fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12 * s),
              Row(
                children: [
                  _Cta(
                    spec: spec,
                    background: bright,
                    foreground: deep,
                  ),
                  SizedBox(width: 10 * s),
                  Expanded(
                    child: Text(
                      spec.hashtags.take(2).join('  '),
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted.withValues(alpha: 0.9),
                        fontSize: 11 * s,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
