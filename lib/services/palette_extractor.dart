import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// يستخرج اللون المسيطر على صورة المنتج ليُبنى عليه التصميم — وهي الحيلة
/// التي تجعل الإعلان يبدو «مصمَّمًا لهذا المنتج» لا قالبًا عامًّا
/// (نفس ما تفعله أدوات التصميم العالمية).
///
/// يعمل بالكامل على الجهاز: تصغير الصورة ثم تجميع الألوان في صناديق
/// (histogram) مع تجاهل الشفاف وشبه الأبيض وشبه الأسود والرمادي الباهت،
/// لأنها خلفيات وظلال لا هوية المنتج.
class PaletteExtractor {
  PaletteExtractor._();

  /// في الاختبارات: تنفيذ متزامن بدل عزل isolate.
  @visibleForTesting
  static bool debugRunSynchronously = false;

  /// يعيد قيمة اللون المسيطر (ARGB) أو null إذا لم يوجد لون ذو دلالة.
  static Future<int?> dominantColor(Uint8List bytes) {
    if (debugRunSynchronously) {
      return Future.sync(() => _dominantSync(bytes));
    }
    return compute(_dominantSync, bytes);
  }

  static int? _dominantSync(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final small = img.copyResize(decoded, width: 72);
    final image = small.convert(numChannels: 4);

    // صندوق لكل 32 درجة لون → 8×8×8 صندوقًا.
    final buckets = <int, _Bucket>{};

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (p.a < 200) continue; // شفاف (خلفية معزولة)

        final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
        final maxC = [r, g, b].reduce((a, c) => a > c ? a : c);
        final minC = [r, g, b].reduce((a, c) => a < c ? a : c);
        final lightness = (maxC + minC) / 2;
        final saturation = maxC == minC
            ? 0.0
            : (maxC - minC) / (255 - (2 * lightness - 255).abs());

        // تجاهل شبه الأبيض/الأسود والرمادي الباهت.
        if (lightness > 235 || lightness < 28) continue;
        if (saturation < 0.18) continue;

        final key = ((r ~/ 32) << 6) | ((g ~/ 32) << 3) | (b ~/ 32);
        final bucket = buckets.putIfAbsent(key, _Bucket.new);
        bucket.add(r, g, b, saturation);
      }
    }

    if (buckets.isEmpty) return null;

    // الأفضلية للصندوق الأكثر تكرارًا مع ترجيح التشبّع — فاللون الحيّ
    // يمثّل المنتج أكثر من كتلة باهتة واسعة.
    _Bucket? best;
    var bestScore = 0.0;
    for (final bucket in buckets.values) {
      final score = bucket.count * (0.6 + bucket.avgSaturation);
      if (score > bestScore) {
        bestScore = score;
        best = bucket;
      }
    }
    if (best == null || best.count < 12) return null;

    return 0xFF000000 |
        (best.avgR.round() << 16) |
        (best.avgG.round() << 8) |
        best.avgB.round();
  }
}

class _Bucket {
  int count = 0;
  double _r = 0, _g = 0, _b = 0, _sat = 0;

  void add(double r, double g, double b, double saturation) {
    count++;
    _r += r;
    _g += g;
    _b += b;
    _sat += saturation;
  }

  double get avgR => _r / count;
  double get avgG => _g / count;
  double get avgB => _b / count;
  double get avgSaturation => _sat / count;
}
