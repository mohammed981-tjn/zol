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
  });

  final AdBrief brief;
  final AdKind kind;
  final String headline;
  final String body;
  final List<String> hashtags;

  /// درجة توافق متوقعة (0-100) على نمط Creative Score في AdCreative.ai.
  final int score;
  final DateTime createdAt;

  String get shareText => '$headline\n$body\n${hashtags.join(' ')}';
}
