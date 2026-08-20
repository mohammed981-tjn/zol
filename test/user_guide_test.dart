import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// حارس دليل الاستخدام.
///
/// دليلٌ يُكتب مرّةً ثم تتغيّر الميزات تحته أسوأ من لا دليل: التاجر يقرأ
/// شرحًا لشيء لم يعد موجودًا فيظنّ العطل في فهمه. والدليل لا يُحدَّث
/// «تلقائيًّا» بأمنية — يُحدَّث لأن نسيانه **يُسقط البناء**.
///
/// فالحارس يربط الدليل بالتطبيق ربطًا يُفحص: كل قسم رئيسي في الواجهة
/// يجب أن يجد له عنوانًا هنا، وكل عنوان يجب أن يحمل شرحًا لا ترويسةً
/// فارغة. ومن أضاف تبويبًا جديدًا ولم يشرحه، سقط اختباره قبل أن يصل
/// التاجر.
void main() {
  final guide = File('docs/USER_GUIDE.md');

  test('الدليل موجود ومحزوم مع التطبيق', () {
    expect(
      guide.existsSync(),
      isTrue,
      reason: 'docs/USER_GUIDE.md محذوف — الشاشة تعرض عطلًا للتاجر',
    );

    // مُعلَن في pubspec، وإلّا حُزم التطبيق بلا الدليل وفشل تحميله على
    // الجهاز بينما يمرّ كل اختبار يقرأ الملفّ من القرص.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('docs/USER_GUIDE.md'),
      isTrue,
      reason: 'الدليل غير مُعلَن في assets — لن يُحزَم مع التطبيق',
    );
  });

  test('كل قسم في الواجهة له شرح في الدليل', () {
    final text = guide.readAsStringSync();

    // أقسام التنقّل تُقرأ من ملفّ الترجمة نفسه لا تُكتب هنا: تبويبٌ
    // يُضاف أو يُعاد تسميته يظهر أثره فورًا بدل أن يبقى الحارس يفحص
    // قائمةً ماتت.
    final arb =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final sections = <String>[
      for (final e in arb.entries)
        if (e.key.startsWith('nav') && e.value is String) e.value as String,
    ];
    expect(sections, isNotEmpty, reason: 'لم يُعثر على أقسام التنقّل');

    final missing = [
      for (final s in sections)
        if (!text.contains('## $s')) s,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'أقسام بلا شرح في الدليل: ${missing.join('، ')} — '
          'أضف «## <اسم القسم>» في docs/USER_GUIDE.md',
    );
  });

  test('لا عنوان فارغ ولا نصّ مؤجَّل', () {
    final lines = guide.readAsStringSync().split('\n');

    // عنوانٌ يليه عنوان يعني قسمًا وُعد به ولم يُكتب.
    final empty = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].startsWith('## ')) continue;
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      if (j >= lines.length || lines[j].startsWith('#')) {
        empty.add(lines[i]);
      }
    }
    expect(empty, isEmpty, reason: 'أقسام بلا شرح: ${empty.join('، ')}');

    // علامات المسوّدة لا تصل التاجر.
    for (final bad in const ['TODO', 'TBD', 'FIXME', 'lorem']) {
      expect(
        guide.readAsStringSync().toLowerCase().contains(bad.toLowerCase()),
        isFalse,
        reason: 'الدليل يحوي «$bad» — نصّ مسوّدة يصل التاجر',
      );
    }
  });
}
