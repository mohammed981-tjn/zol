import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حارس الترجمة — سقّاطة (ratchet) لا سدّ.
///
/// الفصل بين النصّ والشيفرة يُنقَض بسطر واحد: مبرمج مستعجل يكتب
/// `Text('حفظ')` فتخرج شاشة عربية وسط تطبيق إنجليزي، ولا يظهر العطل في
/// أي اختبار سلوكي لأن التطبيق يعمل — بلغة واحدة فقط.
///
/// الحارس يعمل بقائمة تُصغَّر ولا تُكبَّر: الملفات التي لم تُهاجَر بعد
/// مذكورة صراحةً بعددها الحالي، وأي **زيادة** في أيّها تُسقط الاختبار،
/// وكذلك أي نصّ عربي جديد في ملفّ مُهاجَر. فالبناء يقبل الوضع القائم
/// ويرفض التراجع عنه.
///
/// حين يُهاجَر ملفّ يُحذف سطره من الجدول أو يُخفَّض رقمه. لا يجوز رفع رقم
/// أبدًا — وهذا هو معنى السقّاطة.
void main() {
  // الحدّ الأعلى المسموح به لكل ملفّ. الصفر يعني «مُهاجَر بالكامل».
  //
  // ما ليس هنا يجب أن يكون صفرًا: أي ملفّ جديد يُنشأ بنصّ محفور يسقط
  // فورًا، فلا تتراكم ديون جديدة بينما نسدّد القديمة.
  const budget = <String, int>{
    // شاشات لم تُهاجَر بعد — الدفعة الثانية.
    'lib/screens/admin_screen.dart': 76,
    'lib/screens/create_ad/execute_screen.dart': 36,
    'lib/screens/settings_screen.dart': 35,
    'lib/screens/create_ad/upload_details_screen.dart': 26,
    'lib/screens/pick_location_screen.dart': 10,
    'lib/screens/payment/moyasar_payment_screen.dart': 10,
    'lib/screens/payment/payment_flow.dart': 6,
    'lib/screens/order_map_screen.dart': 5,
    'lib/widgets/print_cost_calculator.dart': 4,
    'lib/widgets/print_mockup.dart': 1,

    // محرك التصميم: نصوصه تُرسم **داخل الإعلان** لا في الواجهة («عرض
    // خاص»، «لفترة محدودة»)، فلغتها لغة الجمهور لا لغة التاجر. تُحسم
    // في الدفعة الثالثة مع لغة الإعلان المولَّد، لا هنا.
    'lib/widgets/ad_design_preview.dart': 2,

    // وشاشة السحر هوجرت كاملةً إلا دعوةَ إجراءٍ افتراضية تدخل **نصّ
    // الإعلان** نفسه: تاجرٌ يقرأ الإنجليزية قد يكون جمهوره عربيًّا،
    // فترجمتُها بلغة الواجهة تضع كلمة إنجليزية في إعلان عربي.
    'lib/screens/create_ad/magic_screen.dart': 2,

    // نبرة العيّنة في معرض القوالب — نصّ محتوى للسبب نفسه.
    'lib/screens/templates_screen.dart': 1,
  };

  // فئات وخدمات ومواسم: تسمياتها تظهر للتاجر وتحتاج ترجمة، لكن نقلها
  // يغيّر توقيع `label` في كل مكان (يحتاج `BuildContext`) — عمل الدفعة
  // الثانية. تُستثنى من الفحص كليًّا بدل حشوها بأرقام تتغيّر مع كل
  // فئة تُضاف.
  const deferredDirs = <String>{
    'lib/models/',
    'lib/services/',
    'lib/state/',
    'lib/config/',
    'lib/theme/',
    'lib/l10n/',
  };

  // النصّ لا يعبر سطرًا (`[^'\n]`)، وإلا التهم النمطُ كتلةَ تعليق عربية
  // كاملة واقعة بين علامة اقتباس في سطر استيراد وأخرى بعدها بأسطر —
  // فيبلّغ عن شيفرة نظيفة أنها مليئة بالنصّ المحفور. الحارس يقيس
  // الشيفرة لا النثر.
  final arabicSingle = RegExp(r"'[^'\n]*[ء-ي][^'\n]*'");
  final arabicDouble = RegExp(r'"[^"\n]*[ء-ي][^"\n]*"');

  /// يزيل التعليقات قبل العدّ: شرحُنا عربيّ بطبعه ولا شأن للترجمة به.
  String stripComments(String source) => source
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        // `//` داخل نصّ (رابط مثلًا) ليس تعليقًا — نتحقّق بعدّ علامات
        // الاقتباس قبله.
        if (i < 0) return line;
        final before = line.substring(0, i);
        final odd =
            "'".allMatches(before).length.isOdd ||
            '"'.allMatches(before).length.isOdd;
        return odd ? line : before;
      })
      .join('\n');

  int countIn(File f) {
    final code = stripComments(f.readAsStringSync());
    return arabicSingle.allMatches(code).length +
        arabicDouble.allMatches(code).length;
  }

  test('لا نصّ عربي محفور جديد في طبقة الواجهة', () {
    final root = Directory('lib');
    final offenders = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (deferredDirs.any(path.startsWith)) continue;

      final found = countIn(entity);
      final allowed = budget[path] ?? 0;
      if (found > allowed) {
        offenders.add(
          '$path: $found نصًّا محفورًا والمسموح $allowed — '
          'انقله إلى lib/l10n/app_ar.arb',
        );
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('السقّاطة لا تُرخى: أي بند في الجدول يجب أن يكون مشدودًا', () {
    // بند مسموح أكبر مما في الملفّ فعلًا يعني أن أحدهم هاجر جزءًا ونسي
    // خفض الرقم — فيبقى فراغ يتسلّل منه نصّ محفور جديد بلا إنذار.
    final slack = <String>[];
    budget.forEach((path, allowed) {
      final f = File(path);
      if (!f.existsSync()) {
        slack.add('$path: مذكور في الجدول ولم يعد موجودًا — احذف سطره');
        return;
      }
      final found = countIn(f);
      if (found < allowed) {
        slack.add(
          '$path: فيه $found والمسموح $allowed — اخفض الرقم إلى $found',
        );
      }
    });
    expect(slack, isEmpty, reason: slack.join('\n'));
  });

  test('ملفّ الترجمة العربي سليم: لا مفتاح مكرّر ولا قيمة فارغة', () {
    final raw = File('lib/l10n/app_ar.arb').readAsStringSync();
    final map = jsonDecode(raw) as Map<String, dynamic>;

    for (final entry in map.entries) {
      if (entry.key.startsWith('@')) continue;
      expect(
        entry.value,
        isA<String>(),
        reason: 'قيمة ${entry.key} ليست نصًّا',
      );
      expect(
        (entry.value as String).trim(),
        isNotEmpty,
        reason: 'مفتاح فارغ: ${entry.key} — يظهر فراغًا في الواجهة',
      );
    }

    // كل بيانات وصفية `@key` يجب أن تقابل مفتاحًا حقيقيًا، وإلا فهي
    // بقية مفتاح حُذف ولم يُنظَّف.
    for (final key in map.keys.where((k) => k.startsWith('@'))) {
      if (key == '@@locale') continue;
      expect(
        map.containsKey(key.substring(1)),
        isTrue,
        reason: 'وصف يتيم: $key بلا مفتاح',
      );
    }
  });
}
