import 'dart:ui';

import '../models/design_spec.dart';
import 'art_palette.dart';

/// ترجمة أدوار الألوان إلى ألوان.
///
/// موضعها هنا لا في الطبيب ولا في العارض: كلاهما يترجم، ولو ترجم كلٌّ
/// بنسخته لفحص الطبيبُ لونًا ورسم العارضُ غيره — فيمرّ نصّ غير مقروء
/// من مدقّق يقول إنه فحصه. مصدر حقيقة واحد للترجمة شرطٌ لصحّة الفحص لا
/// ترتيبٌ للشيفرة.
Color resolveColorRole(ColorRole role, ArtPalette art, {Color? behind}) =>
    switch (role) {
      ColorRole.base => art.base,
      ColorRole.deep => art.deep,
      ColorRole.complement => art.complement,
      ColorRole.neutral => art.neutral,
      ColorRole.auto => ArtPalette.inkOn(behind ?? art.deep),
    };

/// اللون الواقع خلف العنصر فعلًا: لوحه إن كان له لوح، وإلا الخلفية.
///
/// «فعلًا» مقصودة: الحكم على التباين يجب أن يكون على ما تحت الحروف لا
/// على الخلفية العامّة، وإلا حُكم على نصّ داخل لوح فاتح بأنه فوق خلفية
/// داكنة فمرّ أبيضَ على أبيض.
Color backgroundBehind(DesignElement e, DesignSpec spec, ArtPalette art) {
  if (e.fill != null) return resolveColorRole(e.fill!, art);
  return spec.backdrop.isLight ? art.neutral : art.deep;
}
