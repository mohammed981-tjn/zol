import 'dart:ui';

import '../models/ad_format.dart';
import '../models/design_spec.dart';
import '../theme/art_palette.dart';
import '../theme/spec_palette.dart';

/// طبيب المواصفة — الحارس بين النموذج اللغوي والتاجر.
///
/// النموذج **سيُخرج تخطيطات رديئة**، وهذا ليس عيبًا فيه بل طبيعته: يقترح
/// ما يبدو معقولًا نصًّا بلا أن يرى ما رسم. فيضع عنوانًا فوق عنوان،
/// وحرفًا على حافّة القصّ، ولونًا لا يُقرأ فوق خلفيته.
///
/// وكانفا تحلّ هذا بمكتبة قوالب بشرية ضخمة تُقيّد المولّد. ونحن نحلّه
/// بالقياس: كل ما بُني في هذا المشروع — الحبر المقيس بـWCAG، والهامش
/// الآمن للطباعة، وصفّ النصّ — يصير هنا **مدقّقًا** لا زينة.
///
/// والمبدأ الحاكم: **يُصلح ما يُصلَح ويُبلّغ عمّا لا يُصلَح.** مدقّقٌ
/// يرفض بلا إصلاح يجعل نصف مخرَجات النموذج مهدورة، ومدقّقٌ يزعم الإصلاح
/// دائمًا يُمرّر تصميمًا مكسورًا وهو يبتسم. فكل تقرير يقول ماذا وجد،
/// وهل أصلحه، وما بقي.
class SpecDoctor {
  const SpecDoctor._();

  /// أدنى تباين مقبول للنصّ. نفس عتبة WCAG AA المستعملة في اللوحة، فلا
  /// تفترق معايير الشاشة عن معايير التصميم.
  static const minContrast = 4.5;

  /// أقصى تغطية مسموحة بين عنصرَي نصّ. التلامس الطفيف تصميم، والتغطية
  /// عطل — والحدّ بينهما رقم لا رأي.
  static const maxTextOverlap = 0.06;

  /// [hasLogo] هل يملك التاجر شعارًا مرفوعًا؟ يحسم مصير عنصر `logo`:
  /// بلا صورة لا يرسم العارض شيئًا، فاسم العلامة الذي وضعه النموذج نصًّا
  /// في ذلك العنصر يختفي من التصميم بصمت.
  ///
  /// [seasonColor] لون الموسم — يجب أن يكون **نفسه** الذي يمرّره العارض.
  /// فحصُ التباين على لونٍ غير الذي يُرسم فحصٌ لتصميم آخر: شارةٌ خضراء
  /// تُقاس على البنفسجيّ فتمرّ، ثم تُرسم بحبر لا يُقرأ عليها.
  static SpecReport review(
    DesignSpec spec, {
    required Color brandColor,
    bool hasLogo = false,
    Color? seasonColor,
  }) {
    final art = paletteFor(spec, brandColor);
    final margin = spec.format.safeMargin;
    final issues = <SpecIssue>[];
    final fixed = <DesignElement>[];

    for (var i = 0; i < spec.elements.length; i++) {
      var e = spec.elements[i];

      // ٠) شعارٌ بلا صورة يحمل نصًّا. النموذج يفعلها كثيرًا: يضع اسم
      //    العلامة في دور `logo` ظنًّا أن الشعار كلمة. والعارض لا يرسم
      //    دور الشعار إلا صورةً، فيضيع اسم التاجر من إعلانه — وهو أسوأ
      //    من عطلٍ ظاهر لأنه لا يُرى.
      if (e.role == ElementRole.logo &&
          !hasLogo &&
          (e.text ?? '').trim().isNotEmpty) {
        issues.add(
          SpecIssue(
            code: SpecIssueCode.textAsLogo,
            element: i,
            message: 'اسم العلامة وُضع في مكان الشعار — حُوّل إلى نصّ ظاهر',
            repaired: true,
          ),
        );
        e = e.copyWith(role: ElementRole.badge);
      }

      // ١) داخل الهامش الآمن. على المطبوع هذا ليس تجميلًا: سكّين القصّ
      //    لا تقع على الخطّ، وشعارٌ على الحافّة يخرج مقصوصًا في ألف نسخة.
      //
      //    والزخرفة تُستثنى وحدها: نزفُها خارج الحافّة **تكوينٌ مقصود**
      //    كما في المطبوعات، وحشرُها داخل الهامش يحوّلها من ركنٍ إلى
      //    بقعةٍ معلّقة في الفراغ. ولا خسارة في قصّها: لا رسالة فيها
      //    تُقصّ، بخلاف الشعار والنصّ.
      final clamped = e.role == ElementRole.ornament
          ? e.rect
          : e.rect.clampInside(margin);
      if (!_sameRect(clamped, e.rect)) {
        issues.add(
          SpecIssue(
            code: SpecIssueCode.outsideSafeArea,
            element: i,
            message:
                '${_roleLabel(e.role)} خارج الهامش الآمن '
                '(${(margin * 100).toStringAsFixed(1)}٪) — أُعيد داخله',
            repaired: true,
          ),
        );
        e = e.copyWith(rect: clamped);
      }

      // ٢) الحبر يُقرأ فوق ما تحته فعلًا.
      if (e.isText) {
        final behind = backgroundBehind(e, spec, art, seasonColor: seasonColor);
        final ink = resolveColorRole(
          e.color,
          art,
          behind: behind,
          seasonColor: seasonColor,
        );
        final ratio = ArtPalette.contrast(behind, ink);
        if (ratio < minContrast) {
          issues.add(
            SpecIssue(
              code: SpecIssueCode.lowContrast,
              element: i,
              message:
                  'تباين ${_roleLabel(e.role)} ${ratio.toStringAsFixed(2)} '
                  'دون $minContrast — حُوّل إلى حبر محسوب',
              repaired: true,
            ),
          );
          e = e.copyWith(color: ColorRole.auto);
        }
      }

      fixed.add(e);
    }

    // ٣) التداخل — يُمسح حتى الاستقرار لا مرّةً واحدة.
    //
    //    المسح المفرد كان يمرّ على الأزواج بالترتيب ويُعدّل القائمة أثناء
    //    مروره: عنصرٌ أُنزل قد يهبط فوق عنصرٍ فُحص قبله، والزوج لا يُزار
    //    ثانيةً أبدًا. فيخرج التقرير `usable == true` والتداخل باقٍ —
    //    وهذا أسوأ من عدم الفحص: يمنحنا ثقةً لا سند لها.
    //
    //    والتغطية لا تخصّ النصّ وحده: `shape` بلوحٍ معتم و`product`
    //    بصورة معتمة يُدفنان العنوان دفنًا تامًّا، والعارض يرسم بترتيب
    //    القائمة فاللاحق فوق السابق. مدقّقٌ يفحص النصّ ضدّ النصّ فقط
    //    يُجيز تصميمًا لا يُرى عنوانه.
    const maxSweeps = 4;
    var sweep = 0;
    var settled = false;
    while (!settled && sweep < maxSweeps) {
      settled = true;
      sweep++;
      for (var i = 0; i < fixed.length && settled; i++) {
        for (var j = i + 1; j < fixed.length && settled; j++) {
          // الحجب يتبع **ترتيب الرسم**: العارض يرسم اللاحق فوق السابق،
          // فالعنصر المعتم لا يحجب إلا نصًّا **قبله** في القائمة.
          //
          // وبلا هذا الشرط يصير شريطٌ ملوّن خلف عنوان — وهو تكوين
          // مقصود وأوضح تسلسل ممكن — «حجبًا» فيُرفض. وقد رفض بالفعل نمط
          // `bandedHeadline` كلّه قبل أن يُقيَّد الفحص بالترتيب.
          final a = fixed[i], b = fixed[j];
          final bOccludesA = a.isText && _isOpaque(b); // j بعد i فيعلوه
          final pairMatters = (a.isText && b.isText) || bOccludesA;
          if (!pairMatters) continue;

          final ratio = a.rect.overlapRatio(b.rect);
          if (ratio <= maxTextOverlap) continue;

          // الحاجب لا يُزاح: موضعه تكوينٌ قصده المصمّم، والنصّ هو الذي
          // يجب أن يُقرأ. فإن كان أحدهما حاجبًا أُزيح النصّ.
          final int upper, lower;
          if (bOccludesA) {
            upper = j;
            lower = i;
          } else {
            upper = a.rect.y <= b.rect.y ? i : j;
            lower = upper == i ? j : i;
          }

          final wanted = fixed[upper].rect.bottom + 0.015;
          final room = 1 - margin - fixed[lower].rect.h;

          if (wanted <= room) {
            fixed[lower] = fixed[lower].copyWith(
              rect: SpecRect(
                fixed[lower].rect.x,
                wanted,
                fixed[lower].rect.w,
                fixed[lower].rect.h,
              ),
            );
            issues.add(
              SpecIssue(
                code: SpecIssueCode.overlap,
                element: lower,
                message:
                    '${_roleLabel(fixed[lower].role)} يغطّي '
                    '${_roleLabel(fixed[upper].role)} '
                    '(${(ratio * 100).round()}٪) — أُنزل تحته',
                repaired: true,
              ),
            );
            // القائمة تغيّرت: يُعاد المسح من أوّله بدل متابعة مقارنات
            // بُنيت على وضعٍ لم يعد قائمًا.
            settled = false;
          } else {
            issues.add(
              SpecIssue(
                code: SpecIssueCode.overlap,
                element: lower,
                message:
                    '${_roleLabel(fixed[lower].role)} يغطّي '
                    '${_roleLabel(fixed[upper].role)} ولا فراغ لإنزاله',
                repaired: false,
              ),
            );
          }
        }
      }
    }

    // بلغ السقف ولمّا يستقرّ: إصلاحٌ يلاحق نفسه. نُبلّغ بلا إصلاح بدل أن
    // نزعم أن التصميم سليم.
    if (!settled) {
      issues.add(
        const SpecIssue(
          code: SpecIssueCode.overlap,
          element: -1,
          message: 'تداخل لا يستقرّ بعد أربع محاولات — التكوين مزدحم',
          repaired: false,
        ),
      );
    }

    // ٤) الأركان التي لا يقوم إعلان بدونها.
    //
    // والعبرة بالنصّ لا بوجود الدور: عنصرُ عنوانٍ نصّه فارغ يمرّ فحص
    // الوجود ويُخرج رول أب ‎85×200‎ سم بلا رسالة — بدرجةٍ كاملة. وقد
    // كان يفعل.
    bool blank(ElementRole r) {
      final e = spec.firstOf(r);
      return e == null || (e.text ?? '').trim().isEmpty;
    }

    if (blank(ElementRole.headline)) {
      issues.add(
        const SpecIssue(
          code: SpecIssueCode.missingHeadline,
          element: -1,
          message: 'لا عنوان في التصميم — إعلانٌ بلا رسالة',
          repaired: false,
        ),
      );
    }
    if (blank(ElementRole.cta)) {
      issues.add(
        const SpecIssue(
          code: SpecIssueCode.missingCta,
          element: -1,
          message: 'لا دعوة إجراء — المشاهد لا يعرف ما يفعل',
          repaired: false,
        ),
      );
    }

    return SpecReport(spec: spec.withElements(fixed), issues: issues);
  }

  /// هل يحجب هذا العنصر ما تحته؟
  ///
  /// المنتج صورة معتمة، والشكل ذو اللوح لوحٌ معتم. أما الشكل بلا لوح
  /// فلا يرسم العارضُ له شيئًا، فلا يحجب. والزخرفة تُرسم خافتةً جدًّا
  /// خلف المحتوى، فعدّها حاجبًا يرفض كل تصميم اختار التاجر زخرفته.
  static bool _isOpaque(DesignElement e) =>
      e.role == ElementRole.product ||
      (e.role == ElementRole.shape && e.fill != null) ||
      (e.role == ElementRole.logo);

  static bool _sameRect(SpecRect a, SpecRect b) =>
      (a.x - b.x).abs() < 1e-9 &&
      (a.y - b.y).abs() < 1e-9 &&
      (a.w - b.w).abs() < 1e-9 &&
      (a.h - b.h).abs() < 1e-9;

  static String _roleLabel(ElementRole r) => switch (r) {
    ElementRole.headline => 'العنوان',
    ElementRole.subhead => 'السطر الثانوي',
    ElementRole.product => 'المنتج',
    ElementRole.cta => 'زرّ الحثّ',
    ElementRole.badge => 'الشارة',
    ElementRole.logo => 'الشعار',
    ElementRole.tags => 'الهاشتاقات',
    ElementRole.shape => 'شكل',
    ElementRole.ornament => 'الزخرفة',
  };
}

enum SpecIssueCode {
  textAsLogo,
  outsideSafeArea,
  lowContrast,
  overlap,
  missingHeadline,
  missingCta,
}

class SpecIssue {
  const SpecIssue({
    required this.code,
    required this.element,
    required this.message,
    required this.repaired,
  });

  final SpecIssueCode code;

  /// فهرس العنصر، و‎-1‎ لعلّة تخصّ التصميم كلّه.
  final int element;
  final String message;
  final bool repaired;

  @override
  String toString() => '${repaired ? '✔' : '✖'} $message';
}

class SpecReport {
  const SpecReport({required this.spec, required this.issues});

  /// المواصفة بعد الإصلاح.
  final DesignSpec spec;
  final List<SpecIssue> issues;

  /// علل بقيت بلا إصلاح. وجودها يعني أن التصميم لا يصلح للعرض كما هو،
  /// فيُعاد الطلب على النموذج بدل أن يُعرض على التاجر ناقصًا.
  List<SpecIssue> get blocking =>
      issues.where((i) => !i.repaired).toList(growable: false);

  bool get usable => blocking.isEmpty;
}
