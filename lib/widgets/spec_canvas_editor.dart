import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/ad_format.dart';
import '../models/design_spec.dart';
import '../theme/app_theme.dart';
import 'spec_renderer.dart';

/// محرّر العناصر المباشر — التاجر يمسك تصميمه بيده.
///
/// قبله كان التخطيط المولَّد **يُقبل أو يُعاد طلبه**: لا شيء بينهما. فمن
/// أعجبه التكوين وأزعجه موضع كلمة واحدة لم يملك إلا أن يحرق محاولة أخرى
/// على النموذج ويقامر بتكوين جديد قد يكون أسوأ.
///
/// وهذا أظهر فرق كان يبقى بيننا وبين كانفا، وليس فرقًا في الذكاء بل في
/// **الملكية**: أداة التصميم تُعطيك بداية ثم تنسحب، ومولّدٌ لا ينسحب
/// يجعل التاجر متفرّجًا على إعلانه.
///
/// وثلاثة قرارات تحكم البناء:
///
///   ١) **الإحداثيات تبقى كسريّة.** ما يسحبه الإصبع يُقسَّم على مقاس
///      اللوحة قبل أن يُكتب في المواصفة. بلا ذلك يختلف ما ضبطه في
///      المعاينة عمّا يخرج من المطبعة.
///
///   ٢) **الحدّ عند الحافّة لا عند الهامش الآمن.** نمنع الخروج من اللوحة
///      ونرسم دليل الهامش خطًّا متقطّعًا يراه ويقرّر. منعُه من تجاوز
///      الهامش يجعل التصميم يقاوم إصبعه، وأكثر التصاميم الجريئة تقع
///      قريبًا من الحافّة عمدًا.
///
///   ٣) **الطبيب يفحص بعد الإفلات لا أثناء السحب.** فحصٌ في كل إطار
///      يقفز بالعنصر تحت الإصبع، وهو أسوأ شعور في أي محرّر.
class SpecCanvasEditor extends StatefulWidget {
  const SpecCanvasEditor({
    super.key,
    required this.spec,
    required this.brandColor,
    required this.onChanged,
    this.onSelected,
    this.product,
    this.logo,
    this.fontFamily,
    this.productScale = 1,
    this.productDx = 0,
    this.productDy = 0,
    this.showWatermark = false,
  });

  final DesignSpec spec;
  final Color brandColor;

  /// يُستدعى عند **إفلات** الإصبع لا في كل إطار: الأب يُعيد الفحص ويحفظ.
  final ValueChanged<DesignSpec> onChanged;

  /// يُبلّغ الأب بالعنصر المحدّد. الاختيار حالةٌ يحتاجها الأب ليعرف أي
  /// زرّ يعرض، وقراءتُه من `GlobalKey` أثناء البناء لا تُعيد بناء الأب
  /// فيبقى زرّه على حاله بعد أن يلمس التاجر عنصرًا.
  final void Function(int? index, DesignElement? element)? onSelected;

  final Uint8List? product;
  final Uint8List? logo;
  final String? fontFamily;
  final double productScale;
  final double productDx;
  final double productDy;
  final bool showWatermark;

  @override
  State<SpecCanvasEditor> createState() => SpecCanvasEditorState();
}

class SpecCanvasEditorState extends State<SpecCanvasEditor> {
  /// العنصر المختار. `null` يعني لا اختيار — والمقابض مخفيّة.
  int? _selected;

  /// المواصفة أثناء السحب. تبقى محلّية حتى الإفلات فلا يُستدعى الطبيب
  /// ولا يُحفظ شيء ستّين مرّة في الثانية.
  DesignSpec? _dragging;

  /// أصغر مقاس يبقى ممسوكًا بالإصبع — ٤٪ من الضلع.
  static const _minSpan = 0.04;

  /// حجم مقبض التحجيم بالبكسل المنطقي. ٤٤ هو أدنى هدف لمس موصى به.
  static const _handle = 44.0;

  DesignSpec get _live => _dragging ?? widget.spec;

  int? get selectedIndex => _selected;
  DesignElement? get selectedElement {
    final i = _selected;
    if (i == null || i < 0 || i >= _live.elements.length) return null;
    return _live.elements[i];
  }

  void select(int? index) {
    setState(() => _selected = index);
    widget.onSelected?.call(index, selectedElement);
  }

  /// يبدّل نصّ العنصر المختار. يُستدعى من الشاشة الحاضنة بعد ورقة تحرير.
  void setSelectedText(String text) {
    final i = _selected;
    if (i == null) return;
    final next = _live.replaceAt(i, _live.elements[i].copyWith(text: text));
    setState(() => _dragging = null);
    widget.onChanged(next);
  }

  void _move(int index, Offset deltaFraction) {
    final e = _live.elements[index];
    final r = e.rect;
    setState(() {
      _dragging = _live.replaceAt(
        index,
        e.copyWith(
          rect: SpecRect(
            (r.x + deltaFraction.dx).clamp(0.0, 1.0 - r.w),
            (r.y + deltaFraction.dy).clamp(0.0, 1.0 - r.h),
            r.w,
            r.h,
          ),
        ),
      );
    });
  }

  void _resize(int index, Offset deltaFraction) {
    final e = _live.elements[index];
    final r = e.rect;
    setState(() {
      _dragging = _live.replaceAt(
        index,
        e.copyWith(
          rect: SpecRect(
            r.x,
            r.y,
            (r.w + deltaFraction.dx).clamp(_minSpan, 1.0 - r.x),
            (r.h + deltaFraction.dy).clamp(_minSpan, 1.0 - r.y),
          ),
        ),
      );
    });
  }

  void _commit() {
    final next = _dragging;
    if (next == null) return;
    setState(() => _dragging = null);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final spec = _live;
    final margin = spec.format.safeMargin;

    return AspectRatio(
      aspectRatio: spec.format.aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              // اللوحة نفسها: نفس العارض الذي يُصدَّر منه، لا نسخة
              // تقريبية. محرّرٌ يرسم غير ما يُصدَّر يكذب على التاجر.
              SpecRenderer(
                spec: spec,
                brandColor: widget.brandColor,
                product: widget.product,
                logo: widget.logo,
                fontFamily: widget.fontFamily,
                productScale: widget.productScale,
                productDx: widget.productDx,
                productDy: widget.productDy,
              ),

              // إلغاء الاختيار بلمسة على الفراغ — قبل المقابض في الترتيب
              // فلا يبتلع لمساتها.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => select(null),
                ),
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _SafeGuide(margin: margin)),
                ),
              ),

              for (var i = 0; i < spec.elements.length; i++)
                _box(context, l, i, spec.elements[i], w, h),
            ],
          );
        },
      ),
    );
  }

  Widget _box(
    BuildContext context,
    L l,
    int i,
    DesignElement e,
    double w,
    double h,
  ) {
    final r = e.rect;
    final chosen = _selected == i;

    return Positioned(
      left: r.x * w,
      top: r.y * h,
      width: r.w * w,
      height: r.h * h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => select(i),
        onPanStart: (_) => select(i),
        onPanUpdate: (d) => _move(i, Offset(d.delta.dx / w, d.delta.dy / h)),
        onPanEnd: (_) => _commit(),
        onPanCancel: _commit,
        child: Semantics(
          label: '${_roleLabel(l, e.role)}${e.text == null ? '' : ' — ${e.text}'}',
          selected: chosen,
          button: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: chosen
                    ? context.scheme.primary
                    : context.scheme.primary.withValues(alpha: 0.18),
                width: chosen ? 2 : 1,
              ),
            ),
            child: chosen
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // مقبض التحجيم في الركن السفلي الأيسر بصريًّا —
                      // موضعٌ ثابت في الاتجاهين فلا يختفي تحت الإصبع في
                      // واجهة تُقرأ من اليمين.
                      Positioned(
                        left: -_handle / 2,
                        bottom: -_handle / 2,
                        width: _handle,
                        height: _handle,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => _resize(
                            i,
                            Offset(-d.delta.dx / w, d.delta.dy / h),
                          ),
                          onPanEnd: (_) => _commit(),
                          onPanCancel: _commit,
                          child: Center(
                            child: Semantics(
                              label: l.editorResizeHandle,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: context.scheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  static String _roleLabel(L l, ElementRole r) => switch (r) {
    ElementRole.headline => l.roleHeadline,
    ElementRole.subhead => l.roleSubhead,
    ElementRole.product => l.roleProduct,
    ElementRole.cta => l.roleCta,
    ElementRole.badge => l.roleBadge,
    ElementRole.logo => l.roleLogo,
    ElementRole.tags => l.roleTags,
    ElementRole.shape => l.roleShape,
  };
}

/// دليل الهامش الآمن — خطّ متقطّع يقول للتاجر أين تقع سكّين القصّ.
///
/// يُرسم ولا يُلزم. المطبوع يُقصّ قريبًا من الحافّة، ومن وضع شعاره خارج
/// الخطّ يستحق أن يعرف قبل ألف نسخة لا بعدها.
class _SafeGuide extends CustomPainter {
  const _SafeGuide({required this.margin});

  final double margin;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      size.width * margin,
      size.height * margin,
      size.width * (1 - margin),
      size.height * (1 - margin),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.45);

    // تقطيع يدوي: `PathEffect` غير متاح في Flutter، ورسم الخطّ متصلًا
    // يبدو إطارًا في التصميم لا دليلًا فوقه.
    const dash = 6.0, gap = 5.0;
    for (final line in [
      [rect.topLeft, rect.topRight],
      [rect.bottomLeft, rect.bottomRight],
      [rect.topLeft, rect.bottomLeft],
      [rect.topRight, rect.bottomRight],
    ]) {
      final a = line[0], b = line[1];
      final total = (b - a).distance;
      if (total <= 0) continue;
      final step = (b - a) / total;
      var t = 0.0;
      while (t < total) {
        final end = (t + dash).clamp(0.0, total);
        canvas.drawLine(a + step * t, a + step * end, paint);
        t = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_SafeGuide old) => old.margin != margin;
}
