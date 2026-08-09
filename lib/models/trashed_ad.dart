import 'generated_ad.dart';

/// إعلان محذوف من مكتبة «إعلاناتي» بانتظار الحذف النهائي أو الاستعادة.
/// يُحذف تلقائيًا بعد [retentionDays] يومًا من تاريخ النقل للسلة.
class TrashedAd {
  const TrashedAd({required this.ad, required this.deletedAt});

  final GeneratedAd ad;
  final DateTime deletedAt;

  static const retentionDays = 30;

  /// الأيام المتبقية قبل الحذف النهائي التلقائي (لا تقل عن صفر).
  int get daysRemaining {
    final elapsed = DateTime.now().difference(deletedAt).inDays;
    final remaining = retentionDays - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  Map<String, dynamic> toJson() => {
    'ad': ad.toJson(),
    'deletedAt': deletedAt.toIso8601String(),
  };

  factory TrashedAd.fromJson(Map<String, dynamic> json) => TrashedAd(
    ad: GeneratedAd.fromJson(json['ad'] as Map<String, dynamic>),
    deletedAt:
        DateTime.tryParse(json['deletedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
