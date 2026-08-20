import 'dart:ui';

import '../models/design_spec.dart';
import 'art_palette.dart';

/// ترجمة أدوار الألوان إلى ألوان.
///
/// موضعها هنا لا في الطبيب ولا في العارض: كلاهما يترجم، ولو ترجم كلٌّ
/// بنسخته لفحص الطبيبُ لونًا ورسم العارضُ غيره — فيمرّ نصّ غير مقروء
/// من مدقّق يقول إنه فحصه. مصدر حقيقة واحد للترجمة شرطٌ لصحّة الفحص لا
/// ترتيبٌ للشيفرة.
/// [seasonColor] لون الموسم الذي اختاره التاجر. غيابه يُسقط دور الموسم
/// إلى `complement`: مواصفةٌ محفوظة في موسمٍ مضى تُفتح بعده فلا يبقى
/// عنصرها بلا لون.
Color resolveColorRole(
  ColorRole role,
  ArtPalette art, {
  Color? behind,
  Color? seasonColor,
}) => switch (role) {
  ColorRole.base => art.base,
  ColorRole.deep => art.deep,
  ColorRole.complement => art.complement,
  ColorRole.neutral => art.neutral,
  ColorRole.season => seasonColor ?? art.complement,
  ColorRole.auto => ArtPalette.inkOn(behind ?? art.deep),
};

/// اللون الواقع خلف العنصر فعلًا: لوحه إن كان له لوح، وإلا الخلفية.
///
/// «فعلًا» مقصودة: الحكم على التباين يجب أن يكون على ما تحت الحروف لا
/// على الخلفية العامّة، وإلا حُكم على نصّ داخل لوح فاتح بأنه فوق خلفية
/// داكنة فمرّ أبيضَ على أبيض.
Color backgroundBehind(
  DesignElement e,
  DesignSpec spec,
  ArtPalette art, {
  Color? seasonColor,
}) {
  if (e.fill != null) {
    return resolveColorRole(e.fill!, art, seasonColor: seasonColor);
  }

  // لوحٌ **سابق** في القائمة يقع تحت هذا العنصر هو ما تحت الحروف فعلًا،
  // لا الخلفية العامّة. العارض يرسم بترتيب القائمة (اللاحق فوق السابق)،
  // فشريطٌ حياديّ رُسم قبل نصٍّ حياديّ يعطي حياديًّا على حياديّ — ويمرّ
  // الفحصَ لأنه قاس اللون على خلفيةٍ لا يراها المشاهد أصلًا.
  final mine = spec.elements.indexOf(e);
  final upto = mine < 0 ? spec.elements.length : mine;
  Color? beneath;
  for (var i = 0; i < upto; i++) {
    final other = spec.elements[i];
    if (other.fill == null) continue;
    // تغطيةٌ جزئية لا تكفي للحكم: الحرف قد يقع خارج اللوح. نأخذ اللوح
    // الذي يبتلع العنصر ابتلاعًا يكاد يكون تامًّا.
    if (other.rect.overlapRatio(e.rect) >= 0.9) {
      beneath = resolveColorRole(other.fill!, art, seasonColor: seasonColor);
    }
  }
  if (beneath != null) return beneath;

  return spec.backdrop.isLight ? art.neutral : art.deep;
}
