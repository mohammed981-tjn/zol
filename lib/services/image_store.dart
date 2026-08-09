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

  static Future<Uint8List> compressForStorage(Uint8List bytes) {
    if (debugRunSynchronously) {
      return Future.sync(() => _compressSync(bytes));
    }
    return compute(_compressSync, bytes);
  }

  static Uint8List _compressSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    // صورة غير مقروءة: تُحفظ كما هي بدل فقدانها.
    if (decoded == null) return bytes;

    final resized = decoded.width > _maxWidth
        ? img.copyResize(decoded, width: _maxWidth)
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
