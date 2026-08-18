import 'dart:convert';
import 'dart:typed_data';

import 'ad_badge.dart';
import 'business_category.dart';
import 'seasonal_theme.dart';

class AdBrief {
  AdBrief({
    required this.productName,
    required this.description,
    required this.tone,
    required this.platform,
    required this.format,
    this.category = BusinessCategory.retail,
    this.imageBytes,
    this.paletteColor,
    this.season,
    this.useDecorativeBackground = false,
    this.brandName,
    this.brandColor,
    this.badge,
    this.productScale = 1,
    this.productDx = 0,
    this.productDy = 0,
  });

  final String productName;
  final String description;
  final String tone;
  final String platform;
  final String format;

  /// نشاط التاجر — يحدد مفردات النص المولَّد ومنافعه ودعوة الإجراء.
  final BusinessCategory category;

  /// صورة المنتج الحقيقية المختارة من الجهاز (null إن لم تُختر بعد).
  final Uint8List? imageBytes;

  /// اللون المسيطر المستخرج من صورة المنتج — يبني عليه محرك القوالب
  /// لوحته حين لا يكون للتاجر لون علامة محدّد.
  final int? paletteColor;

  /// موسم محلي اختياري (اليوم الوطني، رمضان، ...) يضيف طابعًا احتفاليًا
  /// للنص واللوحة والشارة دون تغيير مفردات النشاط نفسها.
  final SeasonalTheme? season;

  /// خلفية مصمَّمة (نمط زخرفي مستوحى من النشاط) بدل التدرّج المسطّح —
  /// خيار بصري بديل، لا يُغيّر ألوان اللوحة (العلامة/الموسم/المنتج).
  final bool useDecorativeBackground;

  /// اسم المتجر من حساب التاجر — يذهب إلى كاتب الإعلان في الخادم فيذكر
  /// العلامة باسمها بدل «متجرنا».
  final String? brandName;

  /// لون العلامة من Brand Kit (عدد فلاتر معتم). يختلف عن [paletteColor]:
  /// هذا اختيار التاجر الصريح، وذاك مستخرج آليًا من صورة المنتج —
  /// والصريح يغلب المستخرَج عند الإرسال للخادم.
  final int? brandColor;

  /// شارة ترويجية اختيارية تُركَّب على التصميم (خصم، عرض خاص، ...).
  final AdBadge? badge;

  /// تحويل صورة المنتج داخل إطارها كما ضبطه التاجر في المحرر.
  ///
  /// كسور لا بكسلات: التصميم يُرسم في المعاينة الصغيرة وفي التصدير عالي
  /// الدقة بنفس النسب، فإزاحة بالبكسل كانت ستنزلق بين المقاسين.
  /// [productDx]/[productDy] نسبة من عرض الإطار وارتفاعه.
  final double productScale;
  final double productDx;
  final double productDy;

  /// هل عُدّل وضع المنتج عن حاله الافتراضي؟
  bool get hasProductTransform =>
      productScale != 1 || productDx != 0 || productDy != 0;

  bool get hasProductImage => imageBytes != null;

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'description': description,
    'tone': tone,
    'platform': platform,
    'format': format,
    'category': category.name,
    'paletteColor': paletteColor,
    if (season != null) 'season': season!.name,
    'useDecorativeBackground': useDecorativeBackground,
    if (brandName != null) 'brandName': brandName,
    if (brandColor != null) 'brandColor': brandColor,
    if (badge != null) 'badge': badge!.name,
    if (hasProductTransform) ...{
      'productScale': productScale,
      'productDx': productDx,
      'productDy': productDy,
    },
    // تُحفظ الصورة (مضغوطة مسبقًا عبر ImageStore) حتى يمكن فتح الإعلان
    // من المكتبة وإعادة تصديره أو طباعته بعد إغلاق التطبيق.
    if (imageBytes != null) 'imageBytes': base64Encode(imageBytes!),
  };

  AdBrief copyWith({
    Uint8List? imageBytes,
    double? productScale,
    double? productDx,
    double? productDy,
  }) => AdBrief(
    productName: productName,
    description: description,
    tone: tone,
    platform: platform,
    format: format,
    category: category,
    imageBytes: imageBytes ?? this.imageBytes,
    paletteColor: paletteColor,
    season: season,
    useDecorativeBackground: useDecorativeBackground,
    brandName: brandName,
    brandColor: brandColor,
    badge: badge,
    productScale: productScale ?? this.productScale,
    productDx: productDx ?? this.productDx,
    productDy: productDy ?? this.productDy,
  );

  factory AdBrief.fromJson(Map<String, dynamic> json) => AdBrief(
    productName: json['productName'] as String? ?? '',
    description: json['description'] as String? ?? '',
    tone: json['tone'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
    format: json['format'] as String? ?? '',
    category: BusinessCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => BusinessCategory.retail,
    ),
    paletteColor: json['paletteColor'] as int?,
    season: SeasonalTheme.values.cast<SeasonalTheme?>().firstWhere(
      (s) => s?.name == json['season'],
      orElse: () => null,
    ),
    useDecorativeBackground: json['useDecorativeBackground'] as bool? ?? false,
    brandName: json['brandName'] as String?,
    brandColor: json['brandColor'] as int?,
    badge: AdBadge.values.cast<AdBadge?>().firstWhere(
      (b) => b?.name == json['badge'],
      orElse: () => null,
    ),
    productScale: (json['productScale'] as num?)?.toDouble() ?? 1,
    productDx: (json['productDx'] as num?)?.toDouble() ?? 0,
    productDy: (json['productDy'] as num?)?.toDouble() ?? 0,
    imageBytes: switch (json['imageBytes']) {
      final String encoded when encoded.isNotEmpty => _tryDecode(encoded),
      _ => null,
    },
  );

  static Uint8List? _tryDecode(String encoded) {
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }
}
