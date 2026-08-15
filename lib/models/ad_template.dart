import 'package:flutter/material.dart';
import 'business_category.dart';

/// قوالب التصميم المتاحة في محرك zol. كل قالب تركيبة مختلفة جذريًا
/// (لا مجرد تبديل ألوان) حتى يجد التاجر ما يناسب منتجه ومنصته.
enum AdTemplate {
  bold,
  split,
  poster,
  spotlight,
  minimal,
  offer,
  testimonial,
  frame,
  urgency,
  circular,
}

extension AdTemplateInfo on AdTemplate {
  String get label => switch (this) {
    AdTemplate.bold => 'جريء',
    AdTemplate.split => 'منقسم',
    AdTemplate.poster => 'ملصق',
    AdTemplate.spotlight => 'بقعة ضوء',
    AdTemplate.minimal => 'أنيق',
    AdTemplate.offer => 'عرض خاص',
    AdTemplate.testimonial => 'رأي عميل',
    AdTemplate.frame => 'إطار',
    AdTemplate.urgency => 'عاجل',
    AdTemplate.circular => 'دائري',
  };

  String get description => switch (this) {
    AdTemplate.bold => 'عنوان كبير ومنتج بارز — الأنسب للعروض',
    AdTemplate.split => 'تقسيم قطري يفصل المنتج عن النص',
    AdTemplate.poster => 'صورة المنتج ملء الإطار مع شريط نصي',
    AdTemplate.spotlight => 'خلفية داكنة وهالة ضوء تُبرز المنتج',
    AdTemplate.minimal => 'خلفية فاتحة وتفاصيل هادئة — مظهر فاخر',
    AdTemplate.offer => 'شارة عرض دائرية تلفت الانتباه فورًا',
    AdTemplate.testimonial => 'شهادة عميل بنجوم تقييم — يبيع بالثقة لا بالسعر',
    AdTemplate.frame => 'إطار زخرفي مزدوج يوحي بالفخامة والهدية',
    AdTemplate.urgency => 'شريط قطري يصرخ بضيق الوقت — للعروض المؤقتة',
    AdTemplate.circular => 'المنتج في قرص دائري ونص يلتفّ حوله',
  };

  IconData get icon => switch (this) {
    AdTemplate.bold => Icons.format_bold,
    AdTemplate.split => Icons.flip,
    AdTemplate.poster => Icons.crop_original,
    AdTemplate.spotlight => Icons.highlight,
    AdTemplate.minimal => Icons.blur_on,
    AdTemplate.offer => Icons.local_offer_outlined,
    AdTemplate.testimonial => Icons.format_quote,
    AdTemplate.frame => Icons.filter_frames_outlined,
    AdTemplate.urgency => Icons.bolt,
    AdTemplate.circular => Icons.circle_outlined,
  };

  /// هل يعتمد القالب على خلفية فاتحة؟ (يحدد لون النص المناسب.)
  bool get isLightSurface =>
      this == AdTemplate.minimal ||
      this == AdTemplate.testimonial ||
      this == AdTemplate.frame;

  /// ترتيب الرواج — الأقل رقمًا هو الأكثر استخدامًا في إعلانات ناجحة،
  /// يُستخدم لترتيب معرض القوالب ووضع شارة «رائج».
  int get trendingRank => switch (this) {
    AdTemplate.bold => 1,
    AdTemplate.offer => 2,
    AdTemplate.testimonial => 3,
    AdTemplate.spotlight => 4,
    AdTemplate.urgency => 5,
    AdTemplate.poster => 6,
    AdTemplate.circular => 7,
    AdTemplate.split => 8,
    AdTemplate.frame => 9,
    AdTemplate.minimal => 10,
  };

  /// أكثر شارة «رائج» تُعرض لأعلى قالبين رواجًا فقط.
  bool get isTrending => trendingRank <= 2;

  /// الأنشطة التي يناسبها هذا القالب غالبًا — يُستخدم لتقديم القالب
  /// الأنسب أولًا حين يكون نشاط التاجر معروفًا.
  List<BusinessCategory> get suitableFor => switch (this) {
    AdTemplate.bold => [
      BusinessCategory.retail,
      BusinessCategory.services,
      BusinessCategory.restaurant,
    ],
    AdTemplate.split => [BusinessCategory.fashion, BusinessCategory.beauty],
    AdTemplate.poster => [
      BusinessCategory.realEstate,
      BusinessCategory.restaurant,
      BusinessCategory.cafe,
    ],
    AdTemplate.spotlight => [
      BusinessCategory.cafe,
      BusinessCategory.sweets,
      BusinessCategory.beauty,
    ],
    AdTemplate.minimal => [
      BusinessCategory.beauty,
      BusinessCategory.fashion,
      BusinessCategory.realEstate,
    ],
    AdTemplate.offer => [
      BusinessCategory.retail,
      BusinessCategory.sweets,
      BusinessCategory.restaurant,
      BusinessCategory.services,
    ],
    AdTemplate.testimonial => [
      BusinessCategory.services,
      BusinessCategory.beauty,
      BusinessCategory.restaurant,
      BusinessCategory.realEstate,
    ],
    AdTemplate.frame => [
      BusinessCategory.sweets,
      BusinessCategory.beauty,
      BusinessCategory.fashion,
    ],
    AdTemplate.urgency => [
      BusinessCategory.retail,
      BusinessCategory.restaurant,
      BusinessCategory.sweets,
      BusinessCategory.services,
    ],
    AdTemplate.circular => [
      BusinessCategory.cafe,
      BusinessCategory.sweets,
      BusinessCategory.restaurant,
    ],
  };
}

/// يقدّم القوالب الأنسب لنشاط التاجر أولًا، ثم الأكثر رواجًا كترتيب ثانوي
/// — لا تحتاج أي بيانات غير المتوفرة أصلًا على الجهاز (نشاط التاجر
/// المحفوظ وترتيب رواج ثابت لكل قالب).
List<AdTemplate> orderTemplatesForBusiness(
  List<AdTemplate> templates,
  BusinessCategory business,
) {
  final ordered = [...templates];
  ordered.sort((a, b) {
    final aMatch = a.suitableFor.contains(business) ? 0 : 1;
    final bMatch = b.suitableFor.contains(business) ? 0 : 1;
    if (aMatch != bMatch) return aMatch.compareTo(bMatch);
    return a.trendingRank.compareTo(b.trendingRank);
  });
  return ordered;
}

/// لوحة ألوان التصميم النهائية — تُبنى بترتيب أولويات:
/// لون العلامة (Brand Kit) ← اللون المستخرج من صورة المنتج ← تدرّج النبرة.
class AdPalette {
  const AdPalette({required this.primary, required this.accent});

  final Color primary;
  final Color accent;

  static const _byTone = {
    'حماسي': (Color(0xFFF96167), Color(0xFFB91D3A)),
    'كوميدي': (Color(0xFFFFB347), Color(0xFFE8590C)),
    'رسمي': (Color(0xFF1F2A5E), Color(0xFF0F1533)),
    'عاطفي': (Color(0xFF7B4397), Color(0xFFC2185B)),
  };

  /// [brandColor] من Brand Kit (هوية دائمة تسبق كل شيء)، فـ[seasonColor]
  /// (اختيار احتفالي صريح لهذا الإعلان)، فـ[productColor] المستخرج
  /// تلقائيًا من صورة المنتج، وأخيرًا تدرّج النبرة كافتراضي.
  factory AdPalette.resolve({
    int? brandColor,
    int? seasonColor,
    int? productColor,
    required String tone,
  }) {
    final source = brandColor ?? seasonColor ?? productColor;
    if (source != null) {
      final base = Color(source);
      return AdPalette(
        primary: base,
        accent: Color.lerp(base, Colors.black, 0.42)!,
      );
    }
    final pair = _byTone[tone] ?? _byTone.values.first;
    return AdPalette(primary: pair.$1, accent: pair.$2);
  }

  /// لون نص مقروء فوق [primary].
  Color get onPrimary =>
      primary.computeLuminance() > 0.55 ? const Color(0xFF14182E) : Colors.white;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [primary, accent],
  );
}
