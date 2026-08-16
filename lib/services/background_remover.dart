import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// عزل خلفية صورة المنتج **على الجهاز بالكامل** — الجزء الثاني من الطبقة 1
/// في استراتيجية الذكاء الاصطناعي.
///
/// الخوارزمية (Dart نقية فتعمل على أندرويد وiOS والويب بلا نماذج ثقيلة):
/// 1. تُقرأ ألوان حواف الصورة لتقدير لون الخلفية وتباينه.
/// 2. تعبئة انتشارية (flood fill) من كل بكسلات الحواف: كل بكسل قريب لونيًا
///    من الخلفية ومتصل بها يُعد خلفية.
/// 3. تُجعل الخلفية شفافة مع تنعيم بسيط للحواف، وتُعاد الصورة PNG.
///
/// تعمل ممتازًا مع صور المنتجات ذات الخلفيات شبه الموحدة (أغلب صور
/// المتاجر). للخلفيات المعقدة يُستبدل التنفيذ بنموذج تجزئة
/// (ML Kit Subject Segmentation / TFLite) عبر نفس الواجهة.
class BackgroundRemover {
  BackgroundRemover._();

  /// في الاختبارات: تنفيذ متزامن بدل عزل isolate (حلقة fake-async في
  /// اختبارات الواجهة لا تُكمل نتائج الـ isolates الحقيقية).
  @visibleForTesting
  static bool debugRunSynchronously = false;

  /// يعيد PNG بخلفية شفافة، أو null إذا تعذر العزل (صورة غير صالحة،
  /// أو الخلفية غير موحدة بما يكفي فيفشل العزل بأمان بدل إتلاف الصورة).
  static Future<Uint8List?> removeBackground(Uint8List bytes) {
    if (debugRunSynchronously) {
      return Future.sync(() => _removeBackgroundSync(bytes));
    }
    return compute(_removeBackgroundSync, bytes);
  }

  static Uint8List? _removeBackgroundSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // تصغير للمعالجة السريعة مع الحفاظ على دقة كافية للتصميم.
    final source = decoded.width > 900
        ? img.copyResize(decoded, width: 900)
        : decoded;
    final image = source.convert(numChannels: 4);
    final w = image.width;
    final h = image.height;

    // 1) تقدير لون الخلفية من إطار الحواف.
    double sumR = 0, sumG = 0, sumB = 0;
    var count = 0;
    void sample(int x, int y) {
      final p = image.getPixel(x, y);
      sumR += p.r;
      sumG += p.g;
      sumB += p.b;
      count++;
    }

    for (var x = 0; x < w; x++) {
      sample(x, 0);
      sample(x, h - 1);
    }
    for (var y = 1; y < h - 1; y++) {
      sample(0, y);
      sample(w - 1, y);
    }
    final bgR = sumR / count, bgG = sumG / count, bgB = sumB / count;

    double variance = 0;
    for (var x = 0; x < w; x++) {
      for (final y in [0, h - 1]) {
        final p = image.getPixel(x, y);
        variance += _dist2(p.r, p.g, p.b, bgR, bgG, bgB);
      }
    }
    variance /= (2 * w);

    // خلفية شديدة التباين = ليست خلفية استوديو موحدة؛ نمتنع عن العزل
    // بدل إخراج نتيجة مشوهة.
    if (variance > 3200) return null;

    // 2) تعبئة انتشارية من الحواف.
    final tolerance = (900 + variance * 2.5).clamp(900.0, 4200.0);
    final isBg = Uint8List(w * h);
    final queue = <int>[];

    void seed(int x, int y) {
      final i = y * w + x;
      if (isBg[i] == 1) return;
      final p = image.getPixel(x, y);
      if (_dist2(p.r, p.g, p.b, bgR, bgG, bgB) < tolerance) {
        isBg[i] = 1;
        queue.add(i);
      }
    }

    for (var x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }

    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      final x = i % w, y = i ~/ w;
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final ni = ny * w + nx;
        if (isBg[ni] == 1) continue;
        final p = image.getPixel(nx, ny);
        if (_dist2(p.r, p.g, p.b, bgR, bgG, bgB) < tolerance) {
          isBg[ni] = 1;
          queue.add(ni);
        }
      }
    }

    // إن كان كل شيء «خلفية» أو لا شيء تقريبًا، فالعزل فشل منطقيًا.
    final bgCount = isBg.where((v) => v == 1).length;
    final ratio = bgCount / (w * h);
    if (ratio < 0.05 || ratio > 0.97) return null;

    // بوابة التمزّق.
    //
    // نسبة المساحة وحدها لا تكفي: قصّ ممزّق تمامًا — ثقوب وبقايا وحواف
    // مسنّنة — يزيل نسبة معقولة فيمرّ منها، ثم يفسد كل قالب يُوضع فيه.
    //
    // الفارق أن الشكل السليم **مضغوط**: محيطه قصير نسبةً إلى مساحته.
    // فمقارنة المحيط الفعلي بمحيط قرص له المساحة نفسها تفضح التمزّق:
    // صورة نظيفة تعطي ٢–٤ (لأن للأشكال الحقيقية تفاصيل)، والممزّقة تتجاوز
    // العشرة لأن كل ثقب وكل سنّ يضيف محيطًا بلا مساحة.
    var fgArea = 0;
    var boundary = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (isBg[y * w + x] == 1) continue;
        fgArea++;
        final touchesBg = (x + 1 < w && isBg[y * w + x + 1] == 1) ||
            (x > 0 && isBg[y * w + x - 1] == 1) ||
            (y + 1 < h && isBg[(y + 1) * w + x] == 1) ||
            (y > 0 && isBg[(y - 1) * w + x] == 1);
        if (touchesBg) boundary++;
      }
    }
    if (fgArea == 0) return null;

    final raggedness = boundary / (4 * math.sqrt(fgArea));
    if (raggedness > 6.0) return null;

    // 3) تفريغ الخلفية وتنعيم الحواف بصف انتقالي نصف شفاف.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (isBg[i] == 1) {
          image.setPixelRgba(x, y, 0, 0, 0, 0);
        } else {
          final nearBg = [
            (x + 1, y),
            (x - 1, y),
            (x, y + 1),
            (x, y - 1),
          ].any((n) {
            final (nx, ny) = n;
            return nx >= 0 &&
                ny >= 0 &&
                nx < w &&
                ny < h &&
                isBg[ny * w + nx] == 1;
          });
          if (nearBg) {
            final p = image.getPixel(x, y);
            image.setPixelRgba(
              x,
              y,
              p.r.toInt(),
              p.g.toInt(),
              p.b.toInt(),
              140,
            );
          }
        }
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  static double _dist2(
    num r1,
    num g1,
    num b1,
    num r2,
    num g2,
    num b2,
  ) {
    final dr = r1 - r2, dg = g1 - g2, db = b1 - b2;
    return (dr * dr + dg * dg + db * db).toDouble();
  }
}
