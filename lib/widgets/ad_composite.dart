import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/generation.dart';
import '../theme/app_theme.dart';

/// يركّب الإعلان: خلفية مولَّدة + نص عربي حقيقي فوقها.
///
/// هذا هو جوهر الحل المعماري للمشكلة التي كشفها البحث: نماذج توليد الصور
/// تُشوّه النص العربي (حروف منفصلة أو معكوسة). فبدل مصارعة النموذج، نطلب منه
/// خلفية بلا أي حروف، ثم نرسم النص هنا بمحرّك Flutter الذي يشكّل العربية
/// تشكيلاً صحيحاً دائماً.
///
/// الفائدة العملية: طباعة عربية سليمة 100%، ونص يبقى قابلاً للتعديل بعد
/// التوليد، وصفر إعادة توليد بسبب حروف مشوّهة.
class AdComposite extends StatelessWidget {
  const AdComposite({
    super.key,
    required this.variant,
    required this.aspectRatio,
    this.background,
    this.showHashtags = true,
  });

  final CopyVariant variant;
  final double aspectRatio;
  final Uint8List? background;
  final bool showHashtags;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            // تعتيم متدرّج يضمن قراءة النص على أي خلفية مولَّدة.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x00000000), Color(0xCC0B1024)],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
              child: SizedBox.expand(),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    variant.headline,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.35,
                      shadows: [Shadow(blurRadius: 8, color: Color(0x99000000))],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    variant.body,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Color(0xFFECEFF7),
                      fontSize: 14,
                      height: 1.6,
                      shadows: [Shadow(blurRadius: 6, color: Color(0x99000000))],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          variant.cta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showHashtags && variant.hashtags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      variant.hashtags.join('  '),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFFB9C2DA),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final bytes = background;
    if (bytes == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.navy, AppColors.navyDarker],
          ),
        ),
        child: SizedBox.expand(),
      );
    }
    return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
