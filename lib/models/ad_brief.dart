import 'dart:convert';
import 'dart:typed_data';

import 'business_category.dart';

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

  bool get hasProductImage => imageBytes != null;

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'description': description,
    'tone': tone,
    'platform': platform,
    'format': format,
    'category': category.name,
    'paletteColor': paletteColor,
    // تُحفظ الصورة (مضغوطة مسبقًا عبر ImageStore) حتى يمكن فتح الإعلان
    // من المكتبة وإعادة تصديره أو طباعته بعد إغلاق التطبيق.
    if (imageBytes != null) 'imageBytes': base64Encode(imageBytes!),
  };

  AdBrief copyWith({Uint8List? imageBytes}) => AdBrief(
    productName: productName,
    description: description,
    tone: tone,
    platform: platform,
    format: format,
    category: category,
    imageBytes: imageBytes ?? this.imageBytes,
    paletteColor: paletteColor,
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
