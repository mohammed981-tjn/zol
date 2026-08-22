import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// استوديو التاجر المنزلي — تحسين بصري كامل على الجهاز، صفر نداءات سحابية.
///
/// صور التجار تُلتقط بإضاءة مطبخ أو مستودع: باهتة، مائلة للرمادي، حوافّ
/// قصّها خشنة. كل قالب يعرضها كما هي فيبدو التصميم «رديًّا» مهما جمُل
/// القالب نفسه. هنا تُعالَج الصورة مرة واحدة عند اختيارها فيرتفع كل ما
/// يُبنى عليها — القوالب المحلية التسعة وصورة المنتج المرسلة للخادم معًا.
///
/// كل دالة تفشل بأمان إلى الأصل: صورة لم تتحسن خير من صورة ضاعت.
class PhotoEnhancer {
  PhotoEnhancer._();

  @visibleForTesting
  static bool debugRunSynchronously = false;

  /// إضاءة وتباين وتشبع تلقائي — يحاكي «تحسين تلقائي» في تطبيقات الكاميرا.
  static Future<Uint8List> enhance(Uint8List bytes) {
    if (debugRunSynchronously) return Future.sync(() => _enhanceSync(bytes));
    return compute(_enhanceSync, bytes);
  }

  /// تنعيم حواف القصاصة — القص الآلي يترك هالة بيضاء وحوافّ مسنّنة
  /// تفضح أن الصورة «ملصوقة». تآكل بكسل واحد يزيل الهالة، وترييش خفيف
  /// يذيب السنّ في الخلفية.
  static Future<Uint8List> polishCutout(Uint8List bytes) {
    if (debugRunSynchronously) return Future.sync(() => _polishSync(bytes));
    return compute(_polishSync, bytes);
  }

  static Uint8List _enhanceSync(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) return bytes;

    // ١) شدّ التباين بالمئينات: نتجاهل أغمق ١٪ وأفتح ١٪ (غالبًا ضوضاء)
    // ونمدّ الباقي على المدى الكامل. البكسلات الشفافة خارج الحساب كي لا
    // تسحب قصاصةٌ معزولةٌ المدى نحو السواد.
    final hist = List<int>.filled(256, 0);
    var counted = 0;
    for (final p in decoded) {
      if (p.a < 16) continue;
      final l = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
      hist[l]++;
      counted++;
    }
    if (counted == 0) return bytes;

    int percentile(double f) {
      final target = (counted * f).round();
      var acc = 0;
      for (var i = 0; i < 256; i++) {
        acc += hist[i];
        if (acc >= target) return i;
      }
      return 255;
    }

    final lo = percentile(0.01), hi = percentile(0.99);
    // صورة مدّاها ممتد أصلًا لا تحتاج شدًّا — التدخل بلا حاجة يفسدها.
    final needsLevels = hi - lo < 235 && hi > lo;
    if (needsLevels) {
      final scale = 255 / (hi - lo);
      for (final p in decoded) {
        if (p.a < 16) continue;
        p.r = ((p.r - lo) * scale).clamp(0, 255);
        p.g = ((p.g - lo) * scale).clamp(0, 255);
        p.b = ((p.b - lo) * scale).clamp(0, 255);
      }
    }

    // ٢) تشبع خفيف — منتجات الطعام والملابس تحيا بألوانها، والمبالغة
    // تجعلها بلاستيكية، فنكتفي بـ١٢٪.
    img.adjustColor(decoded, saturation: 1.12);

    final hasAlpha = decoded.numChannels == 4;
    final encoded = hasAlpha
        ? img.encodePng(decoded)
        : img.encodeJpg(decoded, quality: 92);
    return Uint8List.fromList(encoded);
  }

  static Uint8List _polishSync(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null || decoded.numChannels != 4) return bytes;

    final w = decoded.width, h = decoded.height;
    final srcA = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        srcA[y * w + x] = decoded.getPixel(x, y).a.toInt();
      }
    }

    // تآكل (أدنى الجوار 3×3) يقصّ الهالة، ثم ترييش (متوسط الجوار) يليّن
    // السنّ. تمريرتان على مصفوفة ألفا وحدها — رخيصتان حتى لصور كبيرة.
    final eroded = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var m = 255;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final ny = y + dy, nx = x + dx;
            final v = (ny < 0 || ny >= h || nx < 0 || nx >= w)
                ? 0
                : srcA[ny * w + nx];
            if (v < m) m = v;
          }
        }
        eroded[y * w + x] = m;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0, n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final ny = y + dy, nx = x + dx;
            if (ny < 0 || ny >= h || nx < 0 || nx >= w) continue;
            sum += eroded[ny * w + nx];
            n++;
          }
        }
        final p = decoded.getPixel(x, y);
        p.a = sum ~/ n;
      }
    }

    return Uint8List.fromList(img.encodePng(decoded));
  }
}
