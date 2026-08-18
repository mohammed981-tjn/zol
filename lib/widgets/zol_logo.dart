import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// شعار zol مرسوم أصلًا بـ CustomPainter — يطابق
/// `assets/brand/zol_wordmark.svg` حرفًا بحرف، فيبقى حادًا في أي حجم
/// ولا يحتاج حزمة رسوميات إضافية.
///
/// الإحداثيات مبنية على مساحة تصميم 332×180 وتُقاس تلقائيًا.
class ZolLogo extends StatelessWidget {
  const ZolLogo({
    super.key,
    this.height = 56,
    this.color,
    this.showSpark = true,
  });

  /// ارتفاع الشعار؛ العرض يُحسب بنسبة التصميم.
  final double height;

  /// لون الحروف — أبيض على الخلفيات الداكنة، كحلي على الفاتحة.
  final Color? color;

  /// إظهار شرارة الذكاء الاصطناعي داخل حرف o.
  final bool showSpark;

  static const _designWidth = 332.0;
  static const _designHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    final letterColor =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.navy);
    return SizedBox(
      height: height,
      width: height * (_designWidth / _designHeight),
      child: CustomPaint(
        painter: _ZolLogoPainter(color: letterColor, showSpark: showSpark),
      ),
    );
  }
}

class _ZolLogoPainter extends CustomPainter {
  _ZolLogoPainter({required this.color, required this.showSpark});

  final Color color;
  final bool showSpark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / ZolLogo._designHeight;
    canvas.save();
    canvas.scale(scale);

    final letters = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // z — شريط علوي، قطر، شريط سفلي.
    canvas.drawRRect(
      RRect.fromLTRBR(40, 60, 130, 82, const Radius.circular(4)),
      letters,
    );
    canvas.drawPath(
      Path()
        ..moveTo(108, 60)
        ..lineTo(130, 60)
        ..lineTo(62, 150)
        ..lineTo(40, 150)
        ..close(),
      letters,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(40, 128, 130, 150, const Radius.circular(4)),
      letters,
    );

    // o — حلقة.
    canvas.drawCircle(
      const Offset(200, 105),
      34,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22,
    );

    // l — عمود بامتداد علوي.
    canvas.drawRRect(
      RRect.fromLTRBR(262, 20, 284, 150, const Radius.circular(6)),
      letters,
    );

    if (showSpark) {
      final spark = Path()
        ..moveTo(200, 86)
        ..quadraticBezierTo(204, 101, 219, 105)
        ..quadraticBezierTo(204, 109, 200, 124)
        ..quadraticBezierTo(196, 109, 181, 105)
        ..quadraticBezierTo(196, 101, 200, 86)
        ..close();
      canvas.drawPath(
        spark,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gold, AppColors.coral],
          ).createShader(const Rect.fromLTWH(181, 86, 38, 38)),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZolLogoPainter old) =>
      old.color != color || old.showSpark != showSpark;
}

/// أيقونة zol المربّعة (حرف z مع الشرارة على خلفية كحلية) — تطابق
/// `assets/brand/zol_icon.svg`. تُستخدم داخل التطبيق حيث يلزم رمز مربّع.
class ZolIcon extends StatelessWidget {
  const ZolIcon({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ZolIconPainter()),
    );
  }
}

class _ZolIconPainter extends CustomPainter {
  static const _design = 512.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _design);

    canvas.drawRRect(
      RRect.fromLTRBR(0, 0, _design, _design, const Radius.circular(118)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26326E), Color(0xFF151C42)],
        ).createShader(const Rect.fromLTWH(0, 0, _design, _design)),
    );

    final white = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromLTRBR(140, 152, 372, 204, const Radius.circular(10)),
      white,
    );
    canvas.drawPath(
      Path()
        ..moveTo(320, 152)
        ..lineTo(372, 152)
        ..lineTo(192, 360)
        ..lineTo(140, 360)
        ..close(),
      white,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(140, 308, 372, 360, const Radius.circular(10)),
      white,
    );

    canvas.drawPath(
      Path()
        ..moveTo(374, 96)
        ..quadraticBezierTo(383, 131, 418, 140)
        ..quadraticBezierTo(383, 149, 374, 184)
        ..quadraticBezierTo(365, 149, 330, 140)
        ..quadraticBezierTo(365, 131, 374, 96)
        ..close(),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gold, AppColors.coral],
        ).createShader(const Rect.fromLTWH(330, 96, 88, 88)),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ZolIconPainter oldDelegate) => false;
}
