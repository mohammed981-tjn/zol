import 'package:flutter/material.dart';
import 'ad_template.dart';

/// تصنيف القوالب حسب الغرض — مدخل التطبيق الجديد على نمط Canva:
/// يتصفّح التاجر ويُلهَم أولًا، ثم يرفع صورة منتجه.
///
/// كل فئة تحدّد صيغة الإعلان (نسبة الأبعاد) والقوالب الأنسب لها.
enum TemplateCategory { post, story, reel, banner, card, poster, rollup }

extension TemplateCategoryInfo on TemplateCategory {
  String get label => switch (this) {
    TemplateCategory.post => 'منشور إنستغرام',
    TemplateCategory.story => 'ستوري',
    TemplateCategory.reel => 'ريلز / تيك توك',
    TemplateCategory.banner => 'بنر مطبوع',
    TemplateCategory.card => 'كرت أعمال',
    TemplateCategory.poster => 'ملصق',
    TemplateCategory.rollup => 'رول أب',
  };

  /// كلمات يُبحث بها عن الفئة إضافةً إلى اسمها.
  List<String> get keywords => switch (this) {
    TemplateCategory.post => ['انستقرام', 'إنستغرام', 'مربع', 'بوست', 'منشور'],
    TemplateCategory.story => ['قصة', 'ستوري', 'سناب', 'عمودي'],
    TemplateCategory.reel => ['ريل', 'تيك توك', 'فيديو', 'شورت'],
    TemplateCategory.banner => ['بنر', 'لافتة', 'مطبوع', 'طباعة'],
    TemplateCategory.card => ['كرت', 'بطاقة', 'أعمال', 'كارت'],
    TemplateCategory.poster => ['ملصق', 'بوستر', 'إعلان جداري'],
    TemplateCategory.rollup => ['رول', 'ستاند', 'معرض'],
  };

  IconData get icon => switch (this) {
    TemplateCategory.post => Icons.crop_square_rounded,
    TemplateCategory.story => Icons.smartphone_outlined,
    TemplateCategory.reel => Icons.play_circle_outline,
    TemplateCategory.banner => Icons.flag_outlined,
    TemplateCategory.card => Icons.badge_outlined,
    TemplateCategory.poster => Icons.image_outlined,
    TemplateCategory.rollup => Icons.view_agenda_outlined,
  };

  /// صيغة الإعلان التي تُملأ تلقائيًا عند اختيار الفئة.
  String get adFormat => switch (this) {
    TemplateCategory.post ||
    TemplateCategory.banner ||
    TemplateCategory.card => 'منشور مربع',
    TemplateCategory.story ||
    TemplateCategory.poster ||
    TemplateCategory.rollup => 'ستوري',
    TemplateCategory.reel => 'ريلز',
  };

  /// المنصة المقترحة للفئات الرقمية (تُترك الافتراضية للمطبوعات).
  String get suggestedPlatform => switch (this) {
    TemplateCategory.reel => 'تيك توك',
    TemplateCategory.story => 'سناب شات',
    _ => 'إنستغرام',
  };

  bool get isPrint =>
      this == TemplateCategory.banner ||
      this == TemplateCategory.card ||
      this == TemplateCategory.rollup;

  /// القوالب المعروضة تحت الفئة، مرتّبة بالأنسب لها.
  List<AdTemplate> get templates => switch (this) {
    TemplateCategory.post => [
      AdTemplate.bold,
      AdTemplate.offer,
      AdTemplate.minimal,
      AdTemplate.split,
    ],
    TemplateCategory.story => [
      AdTemplate.spotlight,
      AdTemplate.poster,
      AdTemplate.bold,
      AdTemplate.split,
    ],
    TemplateCategory.reel => [
      AdTemplate.spotlight,
      AdTemplate.bold,
      AdTemplate.poster,
    ],
    TemplateCategory.banner => [
      AdTemplate.bold,
      AdTemplate.split,
      AdTemplate.offer,
    ],
    TemplateCategory.card => [
      AdTemplate.minimal,
      AdTemplate.split,
      AdTemplate.bold,
    ],
    TemplateCategory.poster => [
      AdTemplate.poster,
      AdTemplate.spotlight,
      AdTemplate.minimal,
    ],
    TemplateCategory.rollup => [
      AdTemplate.spotlight,
      AdTemplate.bold,
      AdTemplate.minimal,
    ],
  };

  bool matchesQuery(String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    if (label.contains(q)) return true;
    if (keywords.any((k) => k.contains(q) || q.contains(k))) return true;
    return templates.any((t) => t.label.contains(q));
  }
}
