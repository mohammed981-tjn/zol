/// خط العلامة التجارية (Brand Kit) — يُطبَّق على نصوص تصميم الإعلان فقط
/// (العنوان والدعوة لاتخاذ إجراء)، لا على واجهة التطبيق نفسها.
enum BrandFont { tajawal, cairo, almarai }

extension BrandFontInfo on BrandFont {
  String get label => switch (this) {
    BrandFont.tajawal => 'Tajawal',
    BrandFont.cairo => 'Cairo',
    BrandFont.almarai => 'Almarai',
  };

  String get family => switch (this) {
    BrandFont.tajawal => 'Tajawal',
    BrandFont.cairo => 'Cairo',
    BrandFont.almarai => 'Almarai',
  };
}
