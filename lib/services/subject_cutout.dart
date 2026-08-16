/// قصّ المنتج بنموذج تجزئة على الجهاز.
///
/// خوارزمية الألوان في [BackgroundRemover] تقيس قرب اللون من بكسلات
/// الحافة، فتنجح على خلفية استوديو موحّدة وتنهار على صورة حقيقية: ثقوب
/// وبقايا وحوافّ مسنّنة. النموذج يفهم **ما هو الشيء** لا ما هو لونه،
/// فيقصّ منتجًا على طاولة مزدحمة كما يقصّه على خلفية بيضاء.
///
/// الصورة لا تغادر الجهاز، والنموذج يُحمّل عبر خدمات Play فلا يضخّم حجم
/// التطبيق.
///
/// أندرويد وiOS فقط. على غيرهما — والويب وسطح المكتب — يعيد `null` بهدوء
/// ليسقط المتصل إلى خوارزمية الألوان.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SubjectCutout {
  SubjectCutout._();

  /// في الاختبارات: تعطيل النموذج ليُختبر مسار السقوط وحده.
  @visibleForTesting
  static bool debugDisabled = false;

  static bool get isSupported {
    if (debugDisabled || kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// يعيد PNG بخلفية شفافة، أو `null` إن تعذّر — ولا يرمي أبدًا.
  ///
  /// الرمي هنا يعني سقوط شاشة إنشاء الإعلان كلها لأجل تحسين اختياري،
  /// فأي عطل — نموذج غير مثبَّت، جهاز قديم، ذاكرة ضاقت — يُترجم إلى
  /// `null` ويكمل المسار بخوارزمية الألوان.
  static Future<Uint8List?> cut(Uint8List bytes) async {
    if (!isSupported) return null;

    File? temp;
    SubjectSegmenter? segmenter;
    try {
      final dir = await getTemporaryDirectory();
      temp = File(
        '${dir.path}/zol_cutout_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await temp.writeAsBytes(bytes, flush: true);

      segmenter = SubjectSegmenter(
        options: SubjectSegmenterOptions(
          // موضوع واحد: المنتج. تعدّد المواضيع يعيد قصاصات متفرّقة
          // لا صورةً واحدة صالحة للتصميم.
          enableMultipleSubjects: false,
          enableForegroundBitmap: true,
          enableForegroundConfidenceMask: false,
        ),
      );

      final result = await segmenter.processImage(
        InputImage.fromFilePath(temp.path),
      );

      final fg = result.foregroundBitmap;
      if (fg == null || fg.isEmpty) return null;

      // النموذج يعيد صورة بقناة ألفا. نتحقّق أنها ليست فارغة ولا مصمتة:
      // كلتاهما تعني تجزئة فاشلة لا منتجًا مقصوصًا.
      return _validated(fg);
    } catch (_) {
      return null;
    } finally {
      await segmenter?.close();
      try {
        await temp?.delete();
      } catch (_) {
        // ملف مؤقت عالق لا يستحق إسقاط العملية.
      }
    }
  }

  /// يرفض ناتجًا شفافًا كله أو معتمًا كله.
  ///
  /// النموذج قد ينجح تقنيًا ويفشل عمليًا حين لا يجد موضوعًا واضحًا — فيعيد
  /// قناعًا فارغًا أو كامل الإطار. كلاهما بلا فائدة، والسقوط إلى خوارزمية
  /// الألوان أفضل من عرضه.
  static Uint8List? _validated(Uint8List png) {
    final im = img.decodeImage(png);
    if (im == null) return null;

    final rgba = im.numChannels == 4 ? im : im.convert(numChannels: 4);
    var opaque = 0;
    final total = rgba.width * rgba.height;
    if (total == 0) return null;

    // عيّنة كل ٧ بكسلات: الحكم لا يحتاج مسحًا كاملًا، والصور كبيرة.
    var sampled = 0;
    for (var y = 0; y < rgba.height; y += 7) {
      for (var x = 0; x < rgba.width; x += 7) {
        sampled++;
        if (rgba.getPixel(x, y).a > 128) opaque++;
      }
    }
    if (sampled == 0) return null;

    final ratio = opaque / sampled;
    if (ratio < 0.03 || ratio > 0.97) return null;

    return png;
  }
}
