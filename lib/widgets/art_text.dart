import 'dart:math' as math;

import 'package:flutter/material.dart';

/// صناعة الحرف — الفرق بين إعلان مصمَّم وإعلان مكتوب فيه كلام.
///
/// كانت كل العناوين تُرسم هكذا: حجم ثابت، سطران، وما زاد يُقصّ بثلاث
/// نقاط. أثر ذلك في الواقع أن التاجر يكتب «افتتاح فرعنا الجديد في حي
/// الياسمين» فيقرأ في إعلانه «افتتاح فرعنا الجديد في حي…» — رسالته
/// مبتورة في المنتصف. وحين يكتب سطرًا قصيرًا يبقى الحجم صغيرًا فيضيع
/// نصف الإطار فارغًا.
///
/// هنا ثلاث صنائع يفعلها الصفّاف البشري ولا يفعلها `Text`:
///   ١) **ملء بصري**: الحجم يُحسب لا يُفرض — يكبر حتى يملأ الصندوق
///      ويصغر حتى يتّسع النص كاملًا، فلا بتر ولا فراغ.
///   ٢) **كسر متوازن**: السطران يخرجان متقاربَي الطول بدل سطرٍ ممتلئ
///      وكلمةٍ يتيمة تحته — أشهر ما يفضح النص غير المصفوف.
///   ٣) **قراءة فوق الصور**: ظلّ مزدوج خفيف يفصل الحرف عن أي خلفية بلا
///      صندوق معتم يشوّه التصميم.
///
/// كل الحساب على الجهاز وفي إطار واحد: لا حصة، ولا انتظار، ولا نداء.
class ArtText extends StatelessWidget {
  const ArtText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 2,
    this.minScale = 0.62,
    this.maxScale = 1.35,
    this.textAlign = TextAlign.center,
    this.balance = true,
    this.legible = false,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  /// أدنى نسبة من حجم الخطّ المطلوب يُسمح بالهبوط إليها. تحتها يصير
  /// النص غير مقروء على الجوال، فالبتر عندئذٍ أهون من همسٍ لا يُقرأ.
  final double minScale;

  /// أعلى نسبة يُسمح بالصعود إليها حين يكون النص قصيرًا. بلا سقف يتحوّل
  /// عنوان من كلمتين إلى لافتة تبتلع التصميم.
  final double maxScale;

  final TextAlign textAlign;
  final bool balance;

  /// ظلّ للقراءة فوق الصور. يُطلب صراحةً: إضافته فوق خلفية مسطّحة
  /// تجعل الحرف يبدو متّسخًا بلا سبب.
  final bool legible;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    // ظلّان لا واحد: الأول واسع خافت يصنع فصلًا عن الخلفية، والثاني
    // ضيّق تحت الحرف يعطي حدًّا. ظلّ واحد قويّ يبدو ضبابًا لا فصلًا.
    final effective = legible && style.shadows == null
        ? style.copyWith(
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: (style.fontSize ?? 16) * 0.5,
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          )
        : style;

    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite ? c.maxWidth : 400.0;
        final maxH = c.maxHeight.isFinite ? c.maxHeight : double.infinity;
        final base = effective.fontSize ?? 16.0;

        // التكبير مشروط بمعرفة الارتفاع المتاح. في عمود مفتوح الارتفاع
        // لا أحد يخبرنا كم بقي، فالتكبير هناك يدفع ما تحته خارج الإطار
        // (وهذا ما حدث فعلًا: فاض الشقّ ١٫٦ بكسل في المعاينة الصغيرة).
        // فحين يكون الارتفاع مجهولًا نصغّر فقط ولا نكبّر.
        final ceiling = maxH.isFinite ? base * maxScale : base;

        final fitted = fitFontSize(
          text: text,
          style: effective,
          maxWidth: maxW,
          maxHeight: maxH,
          maxLines: maxLines,
          minSize: base * minScale,
          maxSize: ceiling,
          direction: direction,
        );

        final shown = balance
            ? balanceLines(
                text: text,
                style: effective.copyWith(fontSize: fitted),
                maxWidth: maxW,
                maxLines: maxLines,
                direction: direction,
              )
            : text;

        return Text(
          shown,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          // الكسر المتوازن قرار بصريّ لا لغوي: قارئ الشاشة يجب أن يسمع
          // الجملة متّصلة كما كتبها التاجر لا مقطّعة عند حوافّ الإطار.
          semanticsLabel: shown == text ? null : text,
          style: effective.copyWith(fontSize: fitted),
        );
      },
    );
  }

  /// أكبر حجم خطّ يتّسع فيه النص كاملًا داخل الصندوق ضمن [maxLines].
  ///
  /// بحث ثنائي على ست عشرة خطوة: دقّة كسريّة لا تُرى بالعين وكلفة
  /// إهمالية أمام رسم إطار واحد.
  static double fitFontSize({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required double maxHeight,
    required int maxLines,
    required double minSize,
    required double maxSize,
    required TextDirection direction,
  }) {
    if (text.trim().isEmpty || maxWidth <= 0) return style.fontSize ?? 16;

    bool fits(double size) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: style.copyWith(fontSize: size),
        ),
        maxLines: maxLines,
        textDirection: direction,
      )..layout(maxWidth: maxWidth);
      return !tp.didExceedMaxLines && tp.height <= maxHeight + 0.5;
    }

    if (fits(maxSize)) return maxSize;

    var lo = minSize, hi = maxSize;
    for (var i = 0; i < 16; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// يعيد النص وقد أُدرجت فيه فواصل أسطر تجعل الأسطر متقاربة الطول.
  ///
  /// الطريقة: نجرّب كل مواضع القطع الممكنة بين الكلمات، ونختار التوزيع
  /// الذي يصغّر **أعرض** سطر. هذا هو التوازن كما يقيسه الصفّاف: لا سطر
  /// ممتلئ إلى الحافة وآخر فيه كلمة واحدة.
  ///
  /// إن كان النص يسع سطرًا واحدًا يُترك كما هو — التوازن ليس غاية بذاته.
  static String balanceLines({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
    required TextDirection direction,
  }) {
    final words = text.trim().split(RegExp(r'\s+'));
    if (maxLines < 2 || words.length < 2 || maxWidth <= 0) return text;

    double widthOf(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      return tp.width;
    }

    // سطر واحد يكفي ⇒ لا داعي لكسره.
    if (widthOf(words.join(' ')) <= maxWidth) return text;

    // عدد الأسطر المطلوب فعلًا: أقلّ ما يتّسع فيه النص، لا [maxLines]
    // دائمًا — كسر نصٍّ يسع سطرين إلى ثلاثة يبدّد الحجم بلا مقابل.
    final total = widthOf(words.join(' '));
    final needed = math.min(maxLines, math.max(2, (total / maxWidth).ceil()));

    List<String>? best;
    var bestWidest = double.infinity;

    // بحث شامل على مواضع القطع. العناوين الإعلانية قصيرة (< ١٢ كلمة)
    // فالفضاء صغير؛ وفوق ذلك نكتفي بالقسمة المتساوية بعدد الحروف.
    if (words.length <= 12) {
      final cuts = List<int>.filled(needed - 1, 0);
      void search(int depth, int start) {
        if (depth == needed - 1) {
          final lines = <String>[];
          var prev = 0;
          for (final cut in cuts) {
            lines.add(words.sublist(prev, cut).join(' '));
            prev = cut;
          }
          lines.add(words.sublist(prev).join(' '));
          if (lines.any((l) => l.isEmpty)) return;
          final widest = lines.map(widthOf).reduce(math.max);
          // يجب أن يتّسع كل سطر أولًا؛ التوازن بعد ذلك.
          if (widest <= maxWidth && widest < bestWidest) {
            bestWidest = widest;
            best = lines;
          }
          return;
        }
        for (var i = start; i < words.length - (needed - 1 - depth); i++) {
          cuts[depth] = i + 1;
          search(depth + 1, i + 1);
        }
      }

      search(0, 0);
    }

    if (best != null) return best!.join('\n');

    // احتياط: لم يتّسع أي توزيع (كلمة واحدة أطول من الإطار مثلًا) —
    // نترك النص لآلية Flutter بدل أن نفرض كسرًا أسوأ.
    return text;
  }
}
