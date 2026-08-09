class AdBrief {
  const AdBrief({
    required this.productName,
    required this.description,
    required this.tone,
    required this.platform,
    required this.format,
    required this.hasProductImage,
  });

  final String productName;
  final String description;
  final String tone;
  final String platform;
  final String format;
  final bool hasProductImage;
}
