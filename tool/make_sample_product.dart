// أداة تطوير: توليد صورة منتج تجريبية (كوب قهوة على خلفية موحدة)
// لاختبار عزل الخلفية يدويًا وفي المتصفح.
// التشغيل: dart run tool/make_sample_product.dart <output.png>
import 'dart:io';
import 'package:image/image.dart' as img;

void main(List<String> args) {
  final out = args.isNotEmpty ? args.first : 'sample_product.png';
  final image = img.Image(width: 600, height: 600, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(236, 233, 228, 255));

  // جسم الكوب
  img.fillRect(
    image,
    x1: 200,
    y1: 220,
    x2: 400,
    y2: 460,
    color: img.ColorRgba8(112, 66, 20, 255),
    radius: 28,
  );
  // حزام الكوب
  img.fillRect(
    image,
    x1: 200,
    y1: 300,
    x2: 400,
    y2: 350,
    color: img.ColorRgba8(249, 231, 149, 255),
  );
  // اليد
  img.drawCircle(
    image,
    x: 430,
    y: 320,
    radius: 55,
    color: img.ColorRgba8(112, 66, 20, 255),
  );
  img.fillCircle(
    image,
    x: 430,
    y: 320,
    radius: 40,
    color: img.ColorRgba8(236, 233, 228, 255),
  );
  // بخار
  img.fillCircle(
    image,
    x: 260,
    y: 170,
    radius: 16,
    color: img.ColorRgba8(180, 170, 160, 255),
  );
  img.fillCircle(
    image,
    x: 320,
    y: 140,
    radius: 20,
    color: img.ColorRgba8(180, 170, 160, 255),
  );

  File(out).writeAsBytesSync(img.encodePng(image));
  // ignore: avoid_print
  print('wrote $out');
}
