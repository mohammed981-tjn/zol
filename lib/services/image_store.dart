import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// يضغط صورة المنتج قبل حفظها مع الإعلان في مكتبة «إعلاناتي».
///
/// بلا هذا الضغط كانت الصور الأصلية (حتى 1600 بكسل) تُخزَّن كما هي فينتفخ
/// التخزين المحلي بسرعة. العرض 1000 بكسل يكفي لإعادة التصدير بجودة جيدة.
/// تُحفظ PNG عند وجود شفافية (صورة معزولة الخلفية) وإلا JPEG أخفّ.
class ImageStore {
  ImageStore._();

  @visibleForTesting
  static bool debugRunSynchronously = false;

  static const _maxWidth = 1000;

  /// [maxWidth] لمن يحتاج أصغر من حدّ المكتبة — كقصاصة منتج فوتوغرافية
  /// مفصّلة يتجاوز ترميزها حدَّ الإرسال للخادم فتحتاج تمريرة تصغير ثانية.
  static Future<Uint8List> compressForStorage(
    Uint8List bytes, {
    int maxWidth = _maxWidth,
  }) {
    if (debugRunSynchronously) {
      return Future.sync(() => _compressSync((bytes, maxWidth)));
    }
    return compute(_compressSync, (bytes, maxWidth));
  }

  static Uint8List _compressSync((Uint8List, int) job) {
    final (bytes, maxWidth) = job;
    // decodeImage لا يكتفي بإرجاع null على البيانات التالفة، بل يرمي
    // (ImageException: Invalid IDAT checksum مثلاً). ذلك الاستثناء كان
    // يعبر saveAd فيموت الحفظ صامتاً ويظن التاجر أن إعلانه حُفظ.
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    // صورة غير مقروءة: تُحفظ كما هي بدل فقدانها.
    if (decoded == null) return bytes;

    final resized = decoded.width > maxWidth
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;

    final hasAlpha = resized.numChannels == 4 && _containsTransparency(resized);
    final encoded = hasAlpha
        ? img.encodePng(resized)
        : img.encodeJpg(resized, quality: 85);

    // لا نكبّر الحجم أبدًا: إن كان الأصل أصغر نُبقيه.
    return encoded.length < bytes.length
        ? Uint8List.fromList(encoded)
        : bytes;
  }

  static bool _containsTransparency(img.Image image) {
    for (var y = 0; y < image.height; y += 4) {
      for (var x = 0; x < image.width; x += 4) {
        if (image.getPixel(x, y).a < 250) return true;
      }
    }
    return false;
  }
}
