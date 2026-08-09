import 'dart:typed_data';

/// وصف الإعلان الذي يدخله التاجر — المُدخل الوحيد لكل عملية توليد.
class AdBrief {
  const AdBrief({
    required this.productName,
    required this.tone,
    required this.platform,
    this.productDescription,
    this.productImage,
  });

  final String productName;
  final String tone;
  final String platform;
  final String? productDescription;

  /// صورة المنتج الحقيقية التي اختارها التاجر من جهازه.
  final Uint8List? productImage;

  bool get hasProductImage => productImage != null;

  AdBrief copyWith({
    String? productName,
    String? tone,
    String? platform,
    String? productDescription,
    Uint8List? productImage,
  }) {
    return AdBrief(
      productName: productName ?? this.productName,
      tone: tone ?? this.tone,
      platform: platform ?? this.platform,
      productDescription: productDescription ?? this.productDescription,
      productImage: productImage ?? this.productImage,
    );
  }
}
