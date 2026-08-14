import 'dart:convert';
import 'dart:typed_data';

/// صيغة إعلانية واحدة كما يعيدها المنسّق.
class CopyVariant {
  const CopyVariant({
    required this.angle,
    required this.headline,
    required this.body,
    required this.cta,
    required this.hashtags,
    this.score,
    this.fixNote,
  });

  final String angle;
  final String headline;
  final String body;
  final String cta;
  final List<String> hashtags;

  /// درجة الوكيل الناقد من 10 — يعيدها عقل Supabase لكل صيغة.
  /// تبقى null مع منسّق Node لأنه يرشّح الأفضل ولا يمنح أرقاماً.
  final double? score;

  /// ملاحظة المراجع: ما الذي يرفع هذه الصيغة لو عُدِّلت.
  final String? fixNote;

  factory CopyVariant.fromJson(Map<String, dynamic> json) {
    return CopyVariant(
      angle: (json['angle'] as String?) ?? '',
      headline: (json['headline'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      cta: (json['cta'] as String?) ?? '',
      hashtags: ((json['hashtags'] as List?) ?? const [])
          .whereType<String>()
          .toList(growable: false),
      score: (json['score_total'] as num?)?.toDouble(),
      fixNote: json['fix_note'] as String?,
    );
  }

  CopyVariant copyWith({String? headline, String? body, String? cta}) {
    return CopyVariant(
      angle: angle,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      cta: cta ?? this.cta,
      hashtags: hashtags,
      score: score,
      fixNote: fixNote,
    );
  }
}

/// حالة الحصة اليومية — تُعرض للمستخدم بشفافية بدل مفاجأته بالرفض.
class QuotaStatus {
  const QuotaStatus({required this.used, required this.limit});

  final int used;
  final int limit;

  int get remaining => (limit - used).clamp(0, limit);

  factory QuotaStatus.fromJson(Map<String, dynamic> json) {
    return QuotaStatus(
      used: (json['used'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ناتج المعاينة الكامل.
class PreviewResult {
  const PreviewResult({
    required this.variants,
    required this.bestIndex,
    required this.critiqued,
    required this.quota,
    this.backgroundImage,
    this.aspectRatio = '4:5',
  });

  final List<CopyVariant> variants;

  /// الصيغة التي رشّحها الوكيل الناقد.
  final int bestIndex;

  /// هل جرى تمرير النقد فعلاً؟ (يفشل بصمت دون إفشال الطلب)
  final bool critiqued;

  final QuotaStatus quota;

  /// خلفية المنتج المولَّدة — بلا أي نص داخلها بحكم البرومبت.
  final Uint8List? backgroundImage;

  final String aspectRatio;

  double get aspectRatioValue {
    switch (aspectRatio) {
      case '9:16':
        return 9 / 16;
      case '1:1':
        return 1;
      case '4:5':
      default:
        return 4 / 5;
    }
  }

  /// شكل ردّ دالة `ad-copy` في Supabase.
  ///
  /// تختلف عن منسّق Node في ثلاثة أشياء: الصيغ تصل مرتّبة بالدرجة تنازلياً
  /// (فالأفضل دائماً عند 0)، ولكل صيغة درجة وملاحظة مراجع، ولا تُرجع صورة
  /// ولا حصة — الصورة من دالة `ad-image` والحصة تُدار خارجها.
  factory PreviewResult.fromAdCopyJson(Map<String, dynamic> json) {
    return PreviewResult(
      variants: ((json['variants'] as List?) ?? const [])
          .whereType<Map>()
          .map((v) => CopyVariant.fromJson(v.cast<String, dynamic>()))
          .toList(growable: false),
      bestIndex: 0,
      critiqued: ((json['variants'] as List?) ?? const [])
          .whereType<Map>()
          .any((v) => v['score_total'] != null),
      quota: const QuotaStatus(used: 0, limit: 0),
    );
  }

  factory PreviewResult.fromJson(Map<String, dynamic> json) {
    final copy = (json['copy'] as Map?)?.cast<String, dynamic>() ?? const {};
    final image = (json['image'] as Map?)?.cast<String, dynamic>();

    return PreviewResult(
      variants: ((copy['variants'] as List?) ?? const [])
          .whereType<Map>()
          .map((v) => CopyVariant.fromJson(v.cast<String, dynamic>()))
          .toList(growable: false),
      bestIndex: (copy['bestIndex'] as num?)?.toInt() ?? 0,
      critiqued: copy['critiqued'] == true,
      quota: QuotaStatus.fromJson(
        (json['quota'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      backgroundImage: image == null
          ? null
          : base64Decode(image['base64'] as String),
      aspectRatio: (image?['aspectRatio'] as String?) ?? '4:5',
    );
  }
}
