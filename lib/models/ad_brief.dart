import 'dart:convert';
import 'dart:typed_data';

class AdBrief {
  AdBrief({
    required this.productName,
    required this.description,
    required this.tone,
    required this.platform,
    required this.format,
    this.imageBytes,
    this.paletteColor,
  });

  final String productName;
  final String description;
  final String tone;
  final String platform;
  final String format;

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
    imageBytes: imageBytes ?? this.imageBytes,
    paletteColor: paletteColor,
  );

  factory AdBrief.fromJson(Map<String, dynamic> json) => AdBrief(
    productName: json['productName'] as String? ?? '',
    description: json['description'] as String? ?? '',
    tone: json['tone'] as String? ?? '',
    platform: json['platform'] as String? ?? '',
    format: json['format'] as String? ?? '',
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
