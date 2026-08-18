import 'dart:ui';

import '../models/ad_service.dart';
import 'art_palette.dart';
import '../widgets/art_backdrop.dart';

/// اشتقاق اللوحة الفنية لعناصر السوق.
///
/// المزوّد لا يرفع صورة غلاف ولا يختار لونًا، ومع ذلك يجب أن يتميّز عن
/// جاره في القائمة. الحلّ: نشتقّ لونه من اسمه اشتقاقًا حتميًّا — نفس
/// الاسم يعطي نفس اللون في كل جهاز وكل مرّة، فيصير للمزوّد «هوية» ثابتة
/// يعرفها التاجر قبل أن يقرأ الاسم.
///
/// وهذا يستعمل محرّك الفن نفسه الذي يرسم الإعلانات، فلا يبدو السوق
/// تبويبًا مستوردًا من تطبيق آخر.
ArtPalette paletteForProvider(ServiceProvider p) {
  // درجة اللون من تجزئة الاسم، والتشبّع والإضاءة ثابتان: ترك الثلاثة
  // للتجزئة يُخرج ألوانًا شاحبة أو فاقعة بلا ضابط.
  final hue = (p.id.hashCode.abs() % 360).toDouble();
  return ArtPalette.from(
    _fromHsl(hue, 0.58, 0.46),
    variant: p.kind.index,
  );
}

/// لكل صنف خدمة نمط خلفية يناسب طبيعته: الحركة للحملات، والورق الهادئ
/// للتصميم، وإضاءة المسرح للتصوير.
BackdropStyle backdropForKind(ServiceKind kind) => switch (kind) {
  ServiceKind.printing => BackdropStyle.strata,
  ServiceKind.design => BackdropStyle.mesh,
  ServiceKind.photography => BackdropStyle.spotlight,
  ServiceKind.video => BackdropStyle.arcs,
  ServiceKind.campaign => BackdropStyle.arcs,
  ServiceKind.signage => BackdropStyle.strata,
  ServiceKind.giveaways => BackdropStyle.mesh,
};

Color _fromHsl(double h, double s, double l) {
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
