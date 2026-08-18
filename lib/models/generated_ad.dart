import 'package:flutter/material.dart';
import 'ad_brief.dart';
import 'design_spec.dart';

enum AdKind { video, image, copy }

extension AdKindInfo on AdKind {
  String get label => switch (this) {
    AdKind.video => 'فيديو قصير',
    AdKind.image => 'صورة تسويقية',
    AdKind.copy => 'نص وهاشتاقات',
  };

  IconData get icon => switch (this) {
    AdKind.video => Icons.videocam_outlined,
    AdKind.image => Icons.image_outlined,
    AdKind.copy => Icons.tag_outlined,
  };
}

class GeneratedAd {
  const GeneratedAd({
    required this.brief,
    required this.kind,
    required this.headline,
    required this.body,
    required this.hashtags,
    required this.createdAt,
    this.score,
    this.angle,
    this.cta = 'اطلب الآن',
    this.imageUrl,
    this.imageVerified,
    this.spec,
  });

  final AdBrief brief;
  final AdKind kind;
  final String headline;
  final String body;
  final List<String> hashtags;

  /// درجة توافق متوقعة (0-100) على نمط Creative Score في AdCreative.ai.
  ///
  /// تبقى null حين يأتي الإعلان من المنسّق الخلفي: وكيله الناقد يرشّح
  /// أفضل صيغة ولا يمنح كل صيغة رقماً، فاختلاق رقم هنا يوهم بدقّة
  /// لا مصدر لها. الواجهة تُخفي الشارة عند غيابها.
  final int? score;

  /// زاوية النص التي اختارها المولّد (عرض، منفعة، فضول...) — تأتي من
  /// المنسّق وتحلّ محلّ تسمية النوع في العرض حين تتوفّر.
  final String? angle;
  final DateTime createdAt;

  /// دعوة الإجراء المشتقة من نشاط التاجر (تظهر على زر التصميم).
  final String cta;

  /// إعلان مولَّد صورةً كاملة من السحابة — حين يتوفّر يتقدّم على تركيب
  /// محرك القوالب المحلي في العرض، ويبقى المحلي احتياطاً لفشل التحميل.
  final String? imageUrl;

  /// هل دقّق القارئ الآلي حروف الصورة ووجدها سليمة؟
  final bool? imageVerified;

  /// تخطيط مولَّد بالذكاء بدل قوالب Dart الأحد عشر.
  ///
  /// حين يوجد يتقدّم على محرّك القوالب في كل مكان يُرسم فيه الإعلان —
  /// المعاينة والمحرّر والتصدير — بحقنة واحدة في [AdDesignPreview]. ولو
  /// وُصل في كل شاشة على حدة لاختلف ما يراه التاجر عمّا يُطبع له.
  final DesignSpec? spec;

  String get shareText => '$headline\n$body\n${hashtags.join(' ')}';

  GeneratedAd copyWith({
    AdBrief? brief,
    String? imageUrl,
    bool? imageVerified,
    String? headline,
    String? body,
    String? cta,
    DesignSpec? spec,
  }) => GeneratedAd(
    brief: brief ?? this.brief,
    kind: kind,
    headline: headline ?? this.headline,
    body: body ?? this.body,
    hashtags: hashtags,
    score: score,
    angle: angle,
    createdAt: createdAt,
    cta: cta ?? this.cta,
    imageUrl: imageUrl ?? this.imageUrl,
    imageVerified: imageVerified ?? this.imageVerified,
    spec: spec ?? this.spec,
  );

  Map<String, dynamic> toJson() => {
    'brief': brief.toJson(),
    'kind': kind.index,
    'headline': headline,
    'body': body,
    'hashtags': hashtags,
    if (score != null) 'score': score,
    if (angle != null) 'angle': angle,
    'cta': cta,
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (imageVerified != null) 'imageVerified': imageVerified,
    if (spec != null) 'spec': spec!.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory GeneratedAd.fromJson(Map<String, dynamic> json) => GeneratedAd(
    brief: AdBrief.fromJson(json['brief'] as Map<String, dynamic>),
    kind: AdKind.values[json['kind'] as int? ?? 0],
    headline: json['headline'] as String? ?? '',
    body: json['body'] as String? ?? '',
    hashtags: (json['hashtags'] as List?)?.cast<String>() ?? const [],
    score: json['score'] as int?,
    angle: json['angle'] as String?,
    cta: json['cta'] as String? ?? 'اطلب الآن',
    imageUrl: json['imageUrl'] as String?,
    imageVerified: json['imageVerified'] as bool?,
    spec: json['spec'] is Map
        ? DesignSpec.fromJson((json['spec'] as Map).cast<String, dynamic>())
        : null,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
