import 'package:flutter/material.dart';
import 'ad_brief.dart';

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
    required this.score,
    required this.createdAt,
    this.cta = 'اطلب الآن',
  });

  final AdBrief brief;
  final AdKind kind;
  final String headline;
  final String body;
  final List<String> hashtags;

  /// درجة توافق متوقعة (0-100) على نمط Creative Score في AdCreative.ai.
  final int score;
  final DateTime createdAt;

  /// دعوة الإجراء المشتقة من نشاط التاجر (تظهر على زر التصميم).
  final String cta;

  String get shareText => '$headline\n$body\n${hashtags.join(' ')}';

  GeneratedAd copyWith({AdBrief? brief}) => GeneratedAd(
    brief: brief ?? this.brief,
    kind: kind,
    headline: headline,
    body: body,
    hashtags: hashtags,
    score: score,
    createdAt: createdAt,
    cta: cta,
  );

  Map<String, dynamic> toJson() => {
    'brief': brief.toJson(),
    'kind': kind.index,
    'headline': headline,
    'body': body,
    'hashtags': hashtags,
    'score': score,
    'cta': cta,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GeneratedAd.fromJson(Map<String, dynamic> json) => GeneratedAd(
    brief: AdBrief.fromJson(json['brief'] as Map<String, dynamic>),
    kind: AdKind.values[json['kind'] as int? ?? 0],
    headline: json['headline'] as String? ?? '',
    body: json['body'] as String? ?? '',
    hashtags: (json['hashtags'] as List?)?.cast<String>() ?? const [],
    score: json['score'] as int? ?? 0,
    cta: json['cta'] as String? ?? 'اطلب الآن',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
