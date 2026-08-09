import 'package:flutter/material.dart';

/// قوالب التصميم المتاحة في محرك zol. كل قالب تركيبة مختلفة جذريًا
/// (لا مجرد تبديل ألوان) حتى يجد التاجر ما يناسب منتجه ومنصته.
enum AdTemplate { bold, split, poster, spotlight, minimal, offer }

extension AdTemplateInfo on AdTemplate {
  String get label => switch (this) {
    AdTemplate.bold => 'جريء',
    AdTemplate.split => 'منقسم',
    AdTemplate.poster => 'ملصق',
    AdTemplate.spotlight => 'بقعة ضوء',
    AdTemplate.minimal => 'أنيق',
    AdTemplate.offer => 'عرض خاص',
  };

  String get description => switch (this) {
    AdTemplate.bold => 'عنوان كبير ومنتج بارز — الأنسب للعروض',
    AdTemplate.split => 'تقسيم قطري يفصل المنتج عن النص',
    AdTemplate.poster => 'صورة المنتج ملء الإطار مع شريط نصي',
    AdTemplate.spotlight => 'خلفية داكنة وهالة ضوء تُبرز المنتج',
    AdTemplate.minimal => 'خلفية فاتحة وتفاصيل هادئة — مظهر فاخر',
    AdTemplate.offer => 'شارة عرض دائرية تلفت الانتباه فورًا',
  };

  IconData get icon => switch (this) {
    AdTemplate.bold => Icons.format_bold,
    AdTemplate.split => Icons.flip,
    AdTemplate.poster => Icons.crop_original,
    AdTemplate.spotlight => Icons.highlight,
    AdTemplate.minimal => Icons.blur_on,
    AdTemplate.offer => Icons.local_offer_outlined,
  };

  /// هل يعتمد القالب على خلفية فاتحة؟ (يحدد لون النص المناسب.)
  bool get isLightSurface => this == AdTemplate.minimal;
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

  /// [brandColor] من Brand Kit، و[productColor] المستخرج من صورة المنتج.
  factory AdPalette.resolve({
    int? brandColor,
    int? productColor,
    required String tone,
  }) {
    final source = brandColor ?? productColor;
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
