import 'package:flutter/material.dart';
import '../models/generated_ad.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// محرك قوالب التصميم — الطبقة الأولى من استراتيجية الذكاء (داخل الجهاز
/// 100%): يركّب صورة المنتج الحقيقية على قالب خلفية بألوان تناسب النبرة،
/// مع العنوان والنص والهاشتاقات، فيخرج تصميم إعلاني حقيقي قابل للتصدير
/// كصورة — بدون أي خدمة خارجية.
class AdDesignPreview extends StatelessWidget {
  const AdDesignPreview({super.key, required this.ad, this.showWatermark = true});

  final GeneratedAd ad;

  /// علامة الخطة المجانية المائية (تُزال في الخطة الاحترافية).
  final bool showWatermark;

  static const _gradientsByTone = {
    'حماسي': [Color(0xFFF96167), Color(0xFFB91D3A)],
    'كوميدي': [Color(0xFFFFB347), Color(0xFFF96167)],
    'رسمي': [Color(0xFF1F2A5E), Color(0xFF161E48)],
    'عاطفي': [Color(0xFF7B4397), Color(0xFFDC2430)],
  };

  /// نسبة العرض إلى الارتفاع حسب صيغة الإعلان (منشور مربع أو عمودي).
  double get aspectRatio => ad.brief.format == 'منشور مربع' ? 1 : 9 / 14;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    // لون العلامة (Brand Kit) يتقدم على تدرج النبرة الافتراضي.
    final brand = state.brandColor;
    final colors = brand != null
        ? [brand, Color.lerp(brand, Colors.black, 0.35)!]
        : _gradientsByTone[ad.brief.tone] ?? _gradientsByTone.values.first;
    final image = ad.brief.imageBytes;
    final logo = state.brandLogoBytes;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: colors,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // زخرفة هندسية خفيفة تعطي عمقًا للقالب.
            Positioned(
              top: -40,
              left: -40,
              child: _circle(140, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              bottom: -30,
              right: -30,
              child: _circle(110, Colors.white.withValues(alpha: 0.06)),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    ad.headline,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: image != null
                          ? Image.memory(image, fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                Icons.photo_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ad.brief.productName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ad.hashtags.take(3).join(' '),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'اطلب الآن',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (logo != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(logo, fit: BoxFit.contain),
                ),
              ),
            if (showWatermark)
              Positioned(
                bottom: 8,
                left: 12,
                child: Text(
                  'AdCraft ✦',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
