import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/ad_badge.dart';
import '../models/ad_format.dart';
import '../models/ad_template.dart';
import '../models/brand_font.dart';
import '../models/design_spec.dart';
import '../theme/art_palette.dart';
import 'art_backdrop.dart';
import 'art_text.dart';
import 'product_image.dart';
import 'spec_renderer.dart';
import '../models/generated_ad.dart';
import '../models/seasonal_theme.dart';
import '../state/app_state.dart';

/// اتجاه لوحة الإعلان — من نصّه هو، لا من لغة الواجهة.
///
/// إعلانُ التاجر يخصّ جمهوره، وواجهةُ التطبيق تخصّه هو. وكل محاذاة في
/// محرّك التصميم اتجاهية، فلو تبع الاتجاهُ لغةَ الواجهة لانقلب تصميمٌ
/// عربيّ كامل لأن صاحبه فضّل الإنجليزية في إعداداته — وانتقل الانقلاب
/// إلى الملفّ المصدَّر وإلى ألف نسخة مطبوعة.
///
/// والقاعدة على المحتوى لا على إعداد: أوّل حرف ذي اتجاه قويّ يحسم. وهذا
/// يصحّ اليوم للعربية، ويصحّ غدًا إن ولّدنا إعلانًا إنجليزيًّا.
TextDirection adTextDirection(String sample) {
  for (final rune in sample.runes) {
    // العربية والعبرية والسريانية والثانا — نطاقات الاتجاه القويّ يمينًا.
    if ((rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    // لاتيني قويّ يسارًا.
    if ((rune >= 0x0041 && rune <= 0x005A) ||
        (rune >= 0x0061 && rune <= 0x007A) ||
        (rune >= 0x00C0 && rune <= 0x024F)) {
      return TextDirection.ltr;
    }
  }
  // بلا حرف حاسم: العربية هي لغة التطبيق وجمهوره الأوّل.
  return TextDirection.rtl;
}

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

  /// صيغة اللوحة — منها تُشتقّ النسبة والهامش ومقياس الحرف.
  AdFormat get format => adFormatFromLabel(ad.brief.format);

  /// نسبة العرض إلى الارتفاع حسب صيغة الإعلان.
  double get aspectRatio => format.aspect;

  @override
  Widget build(BuildContext context) {
    // اتجاه اللوحة من **نصّ الإعلان** لا من لغة الواجهة.
    //
    // كل محاذاة في محرّك التصميم اتجاهية (`start`/`end`)، و`ArtText` يصفّ
    // بالاتجاه المحيط. فتاجرٌ يبدّل واجهته إلى الإنجليزية كان ينقلب
    // إعلانه العربي كلّه — والانقلاب ينتقل إلى ملفّ PNG المصدَّر وإلى
    // المطبوع. لغة الواجهة تخصّ التاجر، ولغة الإعلان تخصّ جمهوره.
    return Directionality(
      textDirection: adTextDirection('${ad.headline} ${ad.body} ${ad.cta}'),
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final state = AppStateScope.of(context);

    // تخطيطٌ ركّبه الذكاء يتقدّم على القوالب الأحد عشر.
    //
    // الحقنة هنا لا في كل شاشة على حدة: المعاينة والمحرّر والتصدير
    // والحفظ كلّها تمرّ بهذا العارض، فوصلُه مرّةً يعني أن ما رآه التاجر
    // في شاشة السحر هو نفسه ما يخرج من المطبعة. ولو وُصل في الشاشات
    // فرادى لاختلف المعروض عن المطبوع أوّلَ شاشةٍ نُسيت.
    final generated = ad.spec;
    if (generated != null) {
      return _GeneratedLayout(
        ad: ad,
        spec: generated,
        brandColor: Color(
          state.brandColorValue ?? ad.brief.brandColor ?? 0xFF2C6BED,
        ),
        logo: state.brandLogoBytes,
        fontFamily: state.brandFont?.family,
        showWatermark: showWatermark,
      );
    }

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
            format: format,
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
                  // اللوحة العريضة (كرت أعمال، بنر) تُوجَّه إلى تخطيط
                  // أفقي مهما كان القالب المختار. القوالب الأحد عشر كلها
                  // أعمدة مكدّسة صُمّمت لمربّع: كدسُها في كرت ‎9×5‎ يعطي
                  // شرائح مضغوطة لا تصميمًا. وهوية القالب لا تضيع —
                  // تنتقل إلى نمط الخلفية والتشكيل داخل التخطيط الأفقي.
                  child: spec.shape == AspectClass.wide
                      ? _WideLayout(spec: spec, template: template)
                      : spec.isStand
                      ? _StandLayout(spec: spec, template: template)
                      : switch (template) {
                          AdTemplate.bold => _BoldLayout(spec: spec),
                          AdTemplate.split => _SplitLayout(spec: spec),
                          AdTemplate.poster => _PosterLayout(spec: spec),
                          AdTemplate.spotlight => _SpotlightLayout(spec: spec),
                          AdTemplate.minimal => _MinimalLayout(spec: spec),
                          AdTemplate.offer => _OfferLayout(spec: spec),
                          AdTemplate.testimonial => _TestimonialLayout(
                            spec: spec,
                          ),
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
                        color:
                            (template.isLightSurface
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

/// غلاف التخطيط المولَّد: العارض، وعليه العلامة المائية وحدها.
///
/// لا شارة موسم ولا شارة عرض ولا زخرفة ركن — كلّها هنا **داخل** المواصفة
/// إن أرادها النموذج، وحقنُها من الخارج فوق تكوينٍ لم يحسب لها مكانًا هو
/// بالضبط ما يُنتج التصاميم المزدحمة.
class _GeneratedLayout extends StatelessWidget {
  const _GeneratedLayout({
    required this.ad,
    required this.spec,
    required this.brandColor,
    required this.showWatermark,
    this.logo,
    this.fontFamily,
  });

  final GeneratedAd ad;
  final DesignSpec spec;
  final Color brandColor;
  final bool showWatermark;
  final Uint8List? logo;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    // النسبة هنا **لازمة**: `StackFit.expand` أدناه يُعطي `SpecRenderer`
    // قيودًا محكَمة فتُبطل نسبتَه الداخلية، فيُمطّ الرول أب إلى مربّع
    // ويخرج المطبوع على غير ما رآه التاجر. ومسار القوالب يلفّ نفسه
    // بنسبته، وهذا المسار كان بلا لافّ.
    return AspectRatio(
      aspectRatio: spec.format.aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final s = c.maxWidth / 400;
          return ClipRRect(
            borderRadius: BorderRadius.circular(18 * s),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SpecRenderer(
                  spec: spec,
                  brandColor: brandColor,
                  product: ad.brief.imageBytes,
                  logo: logo,
                  fontFamily: fontFamily,
                  productScale: ad.brief.productScale,
                  productDx: ad.brief.productDx,
                  productDy: ad.brief.productDy,
                ),
                if (showWatermark)
                  Positioned(
                    bottom: 8 * s,
                    left: 12 * s,
                    child: Text(
                      'zol ✦',
                      style: TextStyle(
                        color:
                            (spec.backdrop.isLight
                                    ? Colors.black
                                    : Colors.white)
                                .withValues(alpha: 0.42),
                        fontSize: 10 * s,
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
    required this.format,
    required this.width,
    required this.height,
    required this.palette,
    required this.ad,
    required this.logo,
    this.fontFamily,
  });

  final AdFormat format;
  final double width;
  final double height;
  final AdPalette palette;
  final GeneratedAd ad;
  final Uint8List? logo;

  /// اللوحة الفنية المشتقّة — انسجام كامل من لون واحد بدل درجتين منه.
  ///
  /// البذرة من نصّ الإعلان لا من العشوائية: نفس الإعلان يعطي نفس
  /// اللوحة والخلفية في المعاينة والتصدير وبعد إعادة فتحه من المكتبة.
  late final ArtPalette art = ArtPalette.from(
    palette.primary,
    variant: ad.headline.length + ad.brief.productName.length,
  );

  /// بذرة رسم الخلفية — حتمية كذلك.
  int get seed => ad.headline.hashCode & 0xFFFF;

  /// خط العلامة (Brand Kit) — null يعني اعتماد خط الواجهة الافتراضي.
  final String? fontFamily;

  /// عامل القياس: التصميم مرسوم لعرض ٤٠٠ نقطة، مضروبًا في معامل
  /// الصيغة — الرول أب يُقرأ من ثلاثة أمتار والكرت من ثلاثين سنتيمترًا،
  /// فحرفٌ بنسبة واحدة من العرض لا يصلح لهما معًا.
  double get s => (width / 400) * format.typeScale;

  /// الهامش الآمن بالنقاط: كسرٌ من **أصغر** ضلع لا من العرض، وإلا صار
  /// هامش الرول أب الجانبي هزيلًا وهامش الكرت العلوي مفرطًا.
  double get safe => math.min(width, height) * format.safeMargin;

  AspectClass get shape => format.aspectClass;

  /// لوحة بالغة الطول (رول أب) تحتاج تكوينًا مستقلًّا لا قالبًا مربّعًا
  /// ممدودًا — كما تحتاج اللوحة العريضة.
  bool get isStand => format.aspect < 0.5;

  Uint8List? get image => ad.brief.imageBytes;
  String get headline => ad.headline;
  String get productName => ad.brief.productName;
  List<String> get hashtags => ad.hashtags;

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
    // المعالجة هنا لا في كل قالب: نقطة واحدة تمرّ منها كل صورة في كل
    // تصميم، فلا يبقى قالب بصورة خام ولا تُنسى واحدة عند إضافة قالب.
    final img = ProductImage(
      palette: art,
      // الشعارات والرسوم المسطّحة لا تُرفع تباينًا ولا تُعتَّم أطرافها:
      // الشكل المصمَّم أصلًا يُشوَّه بذلك ولا يتحسّن. والصورة الفوتوغرافية
      // هي وحدها التي تحتاج أن تُدمج في ضوء المشهد.
      child: Image.memory(bytes, fit: fit),
    );
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
    final bright = spec.art.shade(0.82);
    final deep = spec.art.deep;
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
    this.background,
    this.foreground,
    this.outlined = false,
  });

  final _Spec spec;

  /// null ⇒ يُشتقّ من لوحة الإعلان. الافتراضي كان ذهب المنصّة الثابت،
  /// فكان زرّ الحثّ — أهمّ عنصر في الإعلان — يحمل لون zol لا لون التاجر.
  final Color? background;
  final Color? foreground;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final background = this.background ?? spec.art.complement;
    final foreground = this.foreground ?? ArtPalette.inkOn(background);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 18 * spec.s,
        vertical: 8 * spec.s,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : background,
        border: outlined
            ? Border.all(color: foreground, width: 1.4 * spec.s)
            : null,
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
  style: TextStyle(
    color: color.withValues(alpha: 0.85),
    fontSize: 11.5 * spec.s,
  ),
);

// ── 1. جريء ──────────────────────────────────────────────────────────

class _BoldLayout extends StatelessWidget {
  const _BoldLayout({required this.spec});
  final _Spec spec;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    // الحبر يُختار بالتباين فوق الخلفية الفنية الفعلية لا بافتراض
    // «أبيض على ملوّن» — خلفية فاتحة كانت تبتلع نصًّا أبيض.
    final on = spec.art.ink;
    return Stack(
      fit: StackFit.expand,
      children: [
        // خلفية فنية: بؤر متداخلة وحبيبات بدل تدرّج خطّي واحد.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.mesh,
        ),
        Stack(
          children: [
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
                        color: spec.art.neutral,
                        borderRadius: BorderRadius.circular(14 * s),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.32),
                            blurRadius: 18 * s,
                            offset: Offset(0, 8 * s),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      // ظلّ تماسّ يثبّت المنتج على السطح — بلا هالة هنا:
                      // الهالة تفصل المنتج عن خلفية داكنة، أما فوق سطح
                      // فاتح فتلطّخه بلونها وتجعل اللوح يبدو متّسخًا.
                      child: ProductStage(
                        palette: spec.art,
                        halo: false,
                        shadowOpacity: 0.24,
                        child: spec.product(fit: BoxFit.cover),
                      ),
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
                  _Cta(
                    spec: spec,
                    background: spec.art.complement,
                    foreground: ArtPalette.inkOn(spec.art.complement),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
    final on = spec.art.ink;
    return Stack(
      fit: StackFit.expand,
      children: [
        // طبقات قماشية مائلة تحت القطع القطري: القطعُ وحده على لونين
        // مسطّحين كان يقرأ كـ«شريحتَي لون»، لا كتصميم فيه عمق.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.strata,
        ),
        // مثلث قطري بلون العلامة، شبه شفاف ليمرّ منه نسيج الطبقات.
        ClipPath(
          clipper: _DiagonalClipper(),
          child: ColoredBox(color: spec.art.base.withValues(alpha: 0.82)),
        ),
        // أرض النصّ: القطع القطري يمرّ في منتصف كتلة النص، فيقع نصف
        // السطر على لون ونصفه على آخر ويسقط التباين حيث لا يُنتظر.
        // هذا التعتيم يوحّد ما تحت الحروف فيصير الحبر مضمونًا بالحساب.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                spec.art.deep,
                spec.art.deep.withValues(alpha: 0.86),
                spec.art.deep.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.42, 0.62],
            ),
          ),
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
                      color: spec.art.neutral,
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
                    child: ProductStage(
                      palette: spec.art,
                      halo: false,
                      child: spec.product(),
                    ),
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
                      color: spec.art.complement,
                    ),
                    SizedBox(height: 12 * s),
                    ArtText(
                      spec.headline,
                      textAlign: TextAlign.start,
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
        // خلف الصورة فنّ لا لون مسطّح: يظهر حين تكون الصورة معزولة
        // الخلفية، فيقف المنتج المقتطَع على مشهد بدل ورقة باهتة.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.mesh,
        ),
        spec.product(fit: BoxFit.cover),
        // تعتيم سفلي **بلون العلامة** لا بأسود محض: الأسود يقرأ كطبقة
        // افتراضية من محرّر فيديو، والداكن الملوَّن يقرأ كإضاءة مقصودة.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                spec.art.deep.withValues(alpha: 0.94),
                spec.art.deep.withValues(alpha: 0.45),
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
                color: spec.art.complement.withValues(alpha: 0.9),
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
              // فوق صورة: النص يحتاج ظلًّا يفصله، لأن الصورة قد تكون
              // فاتحة تحت الحرف مهما عتّمنا التدرّج.
              ArtText(
                spec.headline,
                textAlign: TextAlign.start,
                legible: true,
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
                  color: spec.art.complement,
                  fontWeight: FontWeight.w600,
                  fontSize: 14 * s,
                ),
              ),
              SizedBox(height: 12 * s),
              _Cta(
                spec: spec,
                background: spec.art.complement,
                foreground: ArtPalette.inkOn(spec.art.complement),
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
        // إضاءة مسرح حقيقية: هالة من الأعلى وقاع يعمّق، وحبيبات تكسر
        // المسطّح الرقمي — بدل تدرّج شعاعي واحد بلون العلامة.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.spotlight,
        ),
        Padding(
          padding: EdgeInsets.all(22 * s),
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: ProductStage(palette: spec.art, child: spec.product()),
              ),
              SizedBox(height: 12 * s),
              Text(
                spec.productName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: spec.art.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 20 * s,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8 * s),
              ArtText(
                spec.headline,
                style: TextStyle(
                  color: spec.art.ink.withValues(alpha: 0.76),
                  fontSize: 13 * s,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 14 * s),
              _Cta(spec: spec, outlined: true, foreground: spec.art.complement),
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
    final ink = spec.art.onInk;
    return Stack(
      fit: StackFit.expand,
      children: [
        // ورق بلون العلامة لا `#F7F5F2` جامد: القالب يبقى فاتحًا متنفّسًا
        // لكنه يصير **ورق التاجر** لا ورقًا عامًّا يصلح لأي أحد.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.paper,
        ),
        Padding(
          padding: EdgeInsets.all(22 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 34 * s, height: 3 * s, color: spec.art.base),
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
              Expanded(
                child: ProductStage(
                  palette: spec.art,
                  halo: false,
                  shadowOpacity: 0.2,
                  child: spec.product(),
                ),
              ),
              SizedBox(height: 12 * s),
              ArtText(
                spec.headline,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.72),
                  fontSize: 13.5 * s,
                  height: 1.45,
                ),
              ),
              SizedBox(height: 12 * s),
              _Cta(
                spec: spec,
                background: spec.art.base,
                foreground: ArtPalette.inkOn(spec.art.base),
              ),
            ],
          ),
        ),
      ],
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
    final on = spec.art.ink;
    return Stack(
      fit: StackFit.expand,
      children: [
        // أقواس منطلقة من الزاوية: إحساس «انفجار عرض» يقابل هدوء التدرّج
        // الخطّي الذي كان هنا — والعرض الخاص لا يُباع بالهدوء.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.arcs,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18 * s, 18 * s, 18 * s, 18 * s),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: spec.art.neutral,
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
              ArtText(
                spec.headline,
                style: TextStyle(
                  color: on.withValues(alpha: 0.86),
                  fontSize: 13 * s,
                  height: 1.35,
                ),
              ),
              SizedBox(height: 10 * s),
              _Cta(
                spec: spec,
                background: spec.art.complement,
                foreground: ArtPalette.inkOn(spec.art.complement),
              ),
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
                // بلون اللوحة المقابل لا بذهب ثابت: شارة العرض يجب أن
                // تقفز من تصميم **هذا** التاجر، لا أن تحمل لون منصّتنا.
                color: spec.art.complement,
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
                  color: ArtPalette.inkOn(spec.art.complement),
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
    final ink = spec.art.onInk;
    return Stack(
      fit: StackFit.expand,
      children: [
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.paper,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24 * s, 26 * s, 24 * s, 20 * s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote,
                size: 40 * s,
                color: spec.art.base.withValues(alpha: 0.35),
              ),
              SizedBox(height: 6 * s),
              Expanded(
                child: Center(
                  // الاقتباس هو بطل هذا القالب: يكبر ليملأ ما أُفرِد له
                  // حين يقصر، ويصغر ليُقرأ كاملًا حين يطول — لا يُبتر.
                  child: ArtText(
                    spec.headline,
                    maxLines: 4,
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
                    child: Icon(
                      Icons.star_rounded,
                      size: 15 * s,
                      color: const Color(0xFFF5A623),
                    ),
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
                        color: spec.art.neutral,
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
                background: spec.art.base,
                foreground: ArtPalette.inkOn(spec.art.base),
              ),
            ],
          ),
        ),
      ],
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
    final ink = spec.art.onInk;
    final gold = spec.art.base;
    return Stack(
      fit: StackFit.expand,
      children: [
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.paper,
        ),
        Padding(
          padding: EdgeInsets.all(12 * s),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: gold.withValues(alpha: 0.55),
                width: 1.2 * s,
              ),
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
                      Expanded(
                        child: ProductStage(
                          palette: spec.art,
                          halo: false,
                          shadowOpacity: 0.16,
                          child: spec.product(),
                        ),
                      ),
                      SizedBox(height: 10 * s),
                      Container(width: 46 * s, height: 1 * s, color: gold),
                      SizedBox(height: 10 * s),
                      ArtText(
                        spec.headline,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15 * s,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12 * s),
                      _Cta(
                        spec: spec,
                        background: gold,
                        foreground: ArtPalette.inkOn(gold),
                      ),
                    ],
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
    final accent = spec.art.complement;
    return Stack(
      fit: StackFit.expand,
      children: [
        // أقواس متسارعة بدل الأسود الجامد `#14161C`: الاستعجال يُرسم
        // حركةً، والمربّع الأسود سكون لا استعجال.
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.arcs,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20 * s, 34 * s, 20 * s, 18 * s),
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: spec.art.neutral,
                    borderRadius: BorderRadius.circular(10 * s),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10 * s),
                    child: spec.product(fit: BoxFit.cover),
                  ),
                ),
              ),
              SizedBox(height: 14 * s),
              ArtText(
                spec.headline,
                maxLines: 3,
                style: TextStyle(
                  color: spec.art.ink,
                  fontSize: 19 * s,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12 * s),
              _Cta(
                spec: spec,
                background: accent,
                foreground: ArtPalette.inkOn(accent),
              ),
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
                        color: ArtPalette.inkOn(accent),
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
    final primary = spec.art.base;
    return Stack(
      fit: StackFit.expand,
      children: [
        ArtBackdrop(
          palette: spec.art,
          seed: spec.seed,
          style: BackdropStyle.paper,
        ),
        Padding(
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
                        // الحلقة تُلقي ظلًّا فتصير قرصًا مرفوعًا عن الورق
                        // لا دائرة مرسومة عليه.
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.22),
                            blurRadius: 18 * s,
                            offset: Offset(0, 7 * s),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColoredBox(
                          color: spec.art.neutral,
                          child: spec.product(fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14 * s),
              ArtText(
                spec.headline,
                style: TextStyle(
                  color: spec.art.onInk,
                  fontSize: 17 * s,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10 * s),
              _Cta(
                spec: spec,
                background: primary,
                foreground: ArtPalette.inkOn(primary),
              ),
            ],
          ),
        ),
      ],
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
    // النغمتان: فاتحة مشرقة للعنوان، وكامدة هادئة للثانوي — من عائلة
    // العلامة نفسها فلا يدخل التصميم لون غريب.
    final bright = spec.art.shade(0.78);
    final muted = spec.art.shade(0.62);
    final deep = spec.art.deep;

    return Container(
      color: deep,
      // هامش البطاقة الداخلية: ٨ من ٤٠٠ = ٢٪ كما في تشريح Canva حرفيًا.
      padding: EdgeInsets.all(8 * s),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12 * s),
          border: Border.all(
            color: bright.withValues(alpha: 0.35),
            width: 1.2 * s,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12 * s),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // بؤر لونية داخل البطاقة: التدرّج الخطّي كان يعطي الاستوديو
              // سطحًا مسطّحًا يفضح أنه قالب، والبؤر تعطيه عمق إضاءة.
              ArtBackdrop(
                palette: spec.art,
                seed: spec.seed,
                style: BackdropStyle.mesh,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16 * s, 20 * s, 16 * s, 14 * s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // العنوان العملاق — يمين الصفحة (بداية القراءة العربية).
                    // يكبر إلى ٣٥٪ فوق حجمه حين يقصر: العنوان العملاق هو سرّ
                    // هذا القالب، وتثبيته على مقاس واحد يهدر نصف أثره.
                    ArtText(
                      spec.headline,
                      textAlign: TextAlign.right,
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
                              color: spec.art.neutral,
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
                          foreground: ArtPalette.inkOn(bright),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── تخطيط اللوحات العريضة (كرت أعمال، بنر) ───────────────────────────
//
// الكرت ليس منشورًا صغيرًا والبنر ليس منشورًا ممدودًا. على لوحة عرضها
// ضعف ارتفاعها، العمود المكدّس يعطي ثلاثة أشرطة رفيعة فوق بعضها: عنوان
// مبتور، صورة مسحوقة، وزرّ بلا مكان. التكوين الصحيح أفقيّ — كتلة نصّية
// إلى جانب المنتج، كما يُصمَّم كل كرت وكل لوحة طريق.
//
// وهذه ليست قالبًا ثاني عشر بل **صنف تخطيط**: القوالب الأحد عشر تمرّ
// منه محتفظةً بشخصيّتها عبر نمط الخلفية، فلا ينفجر العدد إلى ثمانية
// وثمانين تخطيطًا.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.spec, required this.template});
  final _Spec spec;
  final AdTemplate template;

  /// شخصية القالب في اللوحة العريضة: نمط الخلفية وحده يكفي للتمييز،
  /// وتغيير التكوين لكل قالب على سطح ضيّق يُنتج فوضى لا تنوّعًا.
  BackdropStyle get _style => switch (template) {
    AdTemplate.bold || AdTemplate.studio => BackdropStyle.mesh,
    AdTemplate.spotlight || AdTemplate.poster => BackdropStyle.spotlight,
    AdTemplate.offer || AdTemplate.urgency => BackdropStyle.arcs,
    AdTemplate.split || AdTemplate.circular => BackdropStyle.strata,
    _ => BackdropStyle.paper,
  };

  bool get _light => _style == BackdropStyle.paper;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final pad = spec.safe;
    final on = _light ? spec.art.onInk : spec.art.ink;

    return Stack(
      fit: StackFit.expand,
      children: [
        ArtBackdrop(palette: spec.art, seed: spec.seed, style: _style),
        Padding(
          padding: EdgeInsets.all(pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // النصّ أولًا في اتجاه القراءة العربية (يمين)، فالعين تقع
              // على الرسالة قبل الصورة.
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spec.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spec.art.complement,
                        fontWeight: FontWeight.w800,
                        fontSize: 11 * s,
                        letterSpacing: 1.2 * s,
                      ),
                    ),
                    SizedBox(height: 5 * s),
                    Flexible(
                      child: ArtText(
                        spec.headline,
                        textAlign: TextAlign.start,
                        maxLines: 3,
                        style: TextStyle(
                          color: on,
                          fontWeight: FontWeight.w900,
                          // ٤٫٩٪ من العرض — النسبة المقيسة في بنر كانفا
                          // حقيقي، لا رقمًا مختارًا بالذوق.
                          fontSize: spec.width * 0.049,
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: 9 * s),
                    _Cta(spec: spec),
                  ],
                ),
              ),
              SizedBox(width: pad),
              // المنتج غير مركزي — كما في تشريح كانفا: يشغل نحو ٤٢٪ من
              // العرض ويترك للنصّ مساحة تتنفّس بدل أن يتقاسما المنتصف.
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10 * s),
                  child: ProductStage(
                    palette: spec.art,
                    halo: !_light,
                    shadowOpacity: _light ? 0.18 : 0.36,
                    child: spec.product(fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── تخطيط الاستاند (رول أب) ──────────────────────────────────────────
//
// لوحة بنسبة ‎85:200‎ ليست منشورًا ممدودًا. القوالب المربّعة تضع المنتج
// في `Expanded` فيبتلع كل ارتفاع زائد: على مربّع لا يُلاحَظ، وعلى استاند
// بطول مترين يعني صورةً تحتلّ سبعين بالمئة ونصًّا هامشيًّا في الطرفين.
//
// وهذا عكس ما يُصمَّم به الاستاند. الاستاند يُقرأ من ثلاثة أمتار وواقفًا،
// فالترتيب من الأعلى: عنوان كبير عند مستوى النظر، ثم المنتج يسنده، ثم
// دعوةٌ للفعل في الأسفل حيث تصل العين أخيرًا. النِّسَب ثابتة (٣٤٪ /
// ٤٤٪ / ٢٢٪) فلا يبتلع أحدها الآخر مهما طالت اللوحة.
class _StandLayout extends StatelessWidget {
  const _StandLayout({required this.spec, required this.template});
  final _Spec spec;
  final AdTemplate template;

  BackdropStyle get _style => switch (template) {
    AdTemplate.minimal ||
    AdTemplate.frame ||
    AdTemplate.testimonial ||
    AdTemplate.circular => BackdropStyle.paper,
    AdTemplate.offer || AdTemplate.urgency => BackdropStyle.arcs,
    AdTemplate.split => BackdropStyle.strata,
    AdTemplate.spotlight || AdTemplate.poster => BackdropStyle.spotlight,
    _ => BackdropStyle.mesh,
  };

  bool get _light => _style == BackdropStyle.paper;

  @override
  Widget build(BuildContext context) {
    final s = spec.s;
    final on = _light ? spec.art.onInk : spec.art.ink;

    return Stack(
      fit: StackFit.expand,
      children: [
        ArtBackdrop(palette: spec.art, seed: spec.seed, style: _style),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spec.safe,
            vertical: spec.safe * 1.2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      spec.productName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: spec.art.complement,
                        fontWeight: FontWeight.w800,
                        fontSize: 13 * s,
                        letterSpacing: 1.6 * s,
                      ),
                    ),
                    SizedBox(height: 8 * s),
                    // العنوان يملأ ما أُفرِد له: `ArtText` يكبر حين يكون
                    // الارتفاع معلومًا، وهنا هو معلوم بحكم النِّسَب.
                    Expanded(
                      child: ArtText(
                        spec.headline,
                        maxLines: 3,
                        style: TextStyle(
                          color: on,
                          fontWeight: FontWeight.w900,
                          fontSize: spec.width * 0.075,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 44,
                child: ProductStage(
                  palette: spec.art,
                  halo: !_light,
                  shadowOpacity: _light ? 0.18 : 0.4,
                  child: spec.product(),
                ),
              ),
              Expanded(
                flex: 22,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Cta(spec: spec),
                    SizedBox(height: 8 * s),
                    _hashtagLine(spec, on),
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
