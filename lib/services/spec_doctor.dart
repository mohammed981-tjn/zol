import 'dart:ui';

import '../models/ad_format.dart';
import '../models/design_spec.dart';
import '../theme/art_palette.dart';

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

  static SpecReport review(DesignSpec spec, {required Color brandColor}) {
    final art = ArtPalette.from(brandColor, variant: spec.variant);
    final margin = spec.format.safeMargin;
    final issues = <SpecIssue>[];
    final fixed = <DesignElement>[];

    for (var i = 0; i < spec.elements.length; i++) {
      var e = spec.elements[i];

      // ١) داخل الهامش الآمن. على المطبوع هذا ليس تجميلًا: سكّين القصّ
      //    لا تقع على الخطّ، وشعارٌ على الحافّة يخرج مقصوصًا في ألف نسخة.
      final clamped = e.rect.clampInside(margin);
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
        final behind = _behind(e, spec, art);
        final ink = _resolve(e.color, art, behind: behind);
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

    // ٣) التداخل. الإصلاح هنا ليس آليًّا دائمًا: إزاحة عنصر قد تدفعه فوق
    //    ثالث. نُصلح الحالة الواضحة (فراغ تحت الأعلى يكفي) ونُبلّغ عن
    //    غيرها بدل أن ندّعي إصلاحًا يزيد الفوضى.
    for (var i = 0; i < fixed.length; i++) {
      if (!fixed[i].isText) continue;
      for (var j = i + 1; j < fixed.length; j++) {
        if (!fixed[j].isText) continue;
        final ratio = fixed[i].rect.overlapRatio(fixed[j].rect);
        if (ratio <= maxTextOverlap) continue;

        final upper = fixed[i].rect.y <= fixed[j].rect.y ? i : j;
        final lower = upper == i ? j : i;
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

    // ٤) الأركان التي لا يقوم إعلان بدونها.
    if (spec.firstOf(ElementRole.headline) == null) {
      issues.add(
        const SpecIssue(
          code: SpecIssueCode.missingHeadline,
          element: -1,
          message: 'لا عنوان في التصميم — إعلانٌ بلا رسالة',
          repaired: false,
        ),
      );
    }
    if (spec.firstOf(ElementRole.cta) == null) {
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

  /// اللون الذي يقع خلف العنصر فعلًا: لوحه إن كان له لوح، وإلا الخلفية.
  static Color _behind(DesignElement e, DesignSpec spec, ArtPalette art) {
    if (e.fill != null) return _resolve(e.fill!, art);
    return spec.backdrop.isLight ? art.neutral : art.deep;
  }

  static Color _resolve(ColorRole role, ArtPalette art, {Color? behind}) =>
      switch (role) {
        ColorRole.base => art.base,
        ColorRole.deep => art.deep,
        ColorRole.complement => art.complement,
        ColorRole.neutral => art.neutral,
        ColorRole.auto => ArtPalette.inkOn(behind ?? art.deep),
      };

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
  };
}

enum SpecIssueCode {
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
