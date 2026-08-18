import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/ad_format.dart';
import '../models/design_spec.dart';
import '../theme/art_palette.dart';
import '../theme/spec_palette.dart';
import 'art_backdrop.dart';
import 'art_text.dart';
import 'product_image.dart';

/// عارض المواصفة — يرسم **أي** تخطيط لا أحد عشر تخطيطًا.
///
/// القوالب الأحد عشر مكتوبة في Dart، فكل تكوين جديد يحتاج شيفرة وبناءً
/// ونشرًا. وهذا سقفٌ لا يرفعه تحسين القوالب: مهما جمُلت تبقى أحد عشر.
///
/// هنا يُرسم التخطيط من بيانات، فيصير عدد التكوينات مفتوحًا — والنموذج
/// اللغوي يقترح تخطيطًا كما يقترح جملة.
///
/// والعارض **لا يجتهد**: يرسم ما في المواصفة كما هو. كل حكم على الجودة
/// وقع في `SpecDoctor` قبل الوصول إلى هنا. الفصل مقصود — عارضٌ يُصلح
/// أثناء الرسم يُخفي رداءة المخرَج فلا نعرف أن النموذج يُخطئ، ويصعب
/// اختباره لأن ما يُرسم ليس ما في المواصفة.
class SpecRenderer extends StatelessWidget {
  const SpecRenderer({
    super.key,
    required this.spec,
    required this.brandColor,
    this.product,
    this.logo,
    this.fontFamily,
  });

  final DesignSpec spec;
  final Color brandColor;

  /// صورة المنتج. غيابها يرسم مكان المنتج فارغًا بعلامة — لا يُسقط
  /// التصميم: التاجر يرى تكوينه قبل أن يرفع صورته.
  final Uint8List? product;
  final Uint8List? logo;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final art = ArtPalette.from(brandColor, variant: spec.variant);
    final seed = spec.elements.length * 31 + spec.variant;

    return AspectRatio(
      aspectRatio: spec.format.aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          return DefaultTextStyle.merge(
            style: TextStyle(fontFamily: fontFamily),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ArtBackdrop(
                  palette: art,
                  seed: seed,
                  style: _backdrop(spec.backdrop),
                ),
                // الترتيب في القائمة هو ترتيب الطبقات: اللاحق فوق
                // السابق. أبسط قاعدة ممكنة، ويفهمها النموذج بلا حقل
                // `z` يُخطئ فيه.
                for (final e in spec.elements)
                  Positioned(
                    left: e.rect.x * w,
                    top: e.rect.y * h,
                    width: e.rect.w * w,
                    height: e.rect.h * h,
                    child: _element(e, art, w),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _element(DesignElement e, ArtPalette art, double canvasWidth) {
    final behind = backgroundBehind(e, spec, art);
    final ink = resolveColorRole(e.color, art, behind: behind);

    final Widget content = switch (e.role) {
      ElementRole.product => ProductStage(
        palette: art,
        halo: !spec.backdrop.isLight,
        shadowOpacity: spec.backdrop.isLight ? 0.18 : 0.38,
        child: product == null
            ? Center(
                child: Icon(
                  Icons.photo_outlined,
                  size: canvasWidth * 0.12,
                  color: ink.withValues(alpha: 0.4),
                ),
              )
            : ProductImage(
                palette: art,
                child: Image.memory(product!, fit: BoxFit.cover),
              ),
      ),

      ElementRole.logo => logo == null
          ? const SizedBox.shrink()
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(canvasWidth * 0.008),
                child: Image.memory(logo!, fit: BoxFit.contain),
              ),
            ),

      ElementRole.shape => const SizedBox.expand(),

      // كل ما تبقّى نصّ. `ArtText` يقيس ويضبط ويكسر كسرًا متوازنًا، فما
      // يقترحه النموذج من حجم اقتراحٌ لا أمر — والقياس يحسم.
      _ => Align(
        alignment: switch (e.align) {
          SpecAlign.start => AlignmentDirectional.centerStart,
          SpecAlign.center => Alignment.center,
          SpecAlign.end => AlignmentDirectional.centerEnd,
        },
        child: ArtText(
          e.text ?? '',
          maxLines: e.maxLines,
          textAlign: switch (e.align) {
            SpecAlign.start => TextAlign.start,
            SpecAlign.center => TextAlign.center,
            SpecAlign.end => TextAlign.end,
          },
          style: TextStyle(
            color: ink,
            fontWeight: _weight(e.weight),
            fontSize: (e.sizeFactor ?? _defaultSize(e.role)) * canvasWidth,
            height: 1.4, // النسبة المقيسة في تصاميم كانفا الحقيقية.
          ),
        ),
      ),
    };

    if (e.fill == null) return content;

    // اللوح خلف العنصر: هو ما يجعل زرّ الحثّ زرًّا لا نصًّا عائمًا.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolveColorRole(e.fill!, art),
        borderRadius: BorderRadius.circular(
          e.role == ElementRole.cta ? canvasWidth * 0.06 : canvasWidth * 0.02,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: canvasWidth * 0.02),
        child: content,
      ),
    );
  }

  /// أحجام افتراضية حين لا يقترح النموذج حجمًا — ككسر من عرض اللوحة.
  /// العنوان ٤٫٩٪ هي النسبة المقيسة في بنر كانفا حقيقي، لا تقديرًا.
  static double _defaultSize(ElementRole role) => switch (role) {
    ElementRole.headline => 0.049,
    ElementRole.subhead => 0.032,
    ElementRole.cta => 0.030,
    ElementRole.badge => 0.026,
    ElementRole.tags => 0.024,
    _ => 0.030,
  };

  static FontWeight _weight(int w) => switch (w ~/ 100) {
    <= 3 => FontWeight.w300,
    4 => FontWeight.w400,
    5 => FontWeight.w500,
    6 => FontWeight.w600,
    7 => FontWeight.w700,
    8 => FontWeight.w800,
    _ => FontWeight.w900,
  };

  static BackdropStyle _backdrop(SpecBackdrop s) => switch (s) {
    SpecBackdrop.mesh => BackdropStyle.mesh,
    SpecBackdrop.spotlight => BackdropStyle.spotlight,
    SpecBackdrop.arcs => BackdropStyle.arcs,
    SpecBackdrop.strata => BackdropStyle.strata,
    SpecBackdrop.paper => BackdropStyle.paper,
  };
}
