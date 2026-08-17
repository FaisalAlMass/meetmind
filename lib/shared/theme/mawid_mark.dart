import 'package:flutter/material.dart';

/// علامة "موعد" — حرف الميم داخل حلقة، مع نقطة تمثّل لحظة محجوزة.
/// ترسم بالكود مباشرة (مو صورة) عشان تتكيّف تلقائيًا مع ألوان الثيم
/// الحالي (فاتح/داكن).
class MawidMark extends StatelessWidget {
  const MawidMark({
    super.key,
    this.size = 40,
    this.letterColor,
    this.ringColor,
    this.dotColor,
  });

  final double size;

  /// ألوان اختيارية — تلقائيًا تاخذ ألوان الثيم الحالي، بس ممكن تفرضها
  /// لو العلامة فوق خلفية ملوّنة (زي primaryContainer) تحتاج تباين مختلف.
  final Color? letterColor;
  final Color? ringColor;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MawidMarkPainter(
          ringColor: ringColor ?? cs.primary.withValues(alpha: 0.45),
          letterColor: letterColor ?? cs.onSurface,
          dotColor: dotColor ?? cs.tertiary,
        ),
      ),
    );
  }
}

class _MawidMarkPainter extends CustomPainter {
  _MawidMarkPainter({
    required this.ringColor,
    required this.letterColor,
    required this.dotColor,
  });

  final Color ringColor;
  final Color letterColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035;
    canvas.drawCircle(
        center, radius - ringPaint.strokeWidth, ringPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'م',
        style: TextStyle(
          fontSize: size.width * 0.56,
          fontWeight: FontWeight.w800,
          color: letterColor,
          height: 1,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 + size.height * 0.02,
      ),
    );

    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.28),
      size.width * 0.065,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MawidMarkPainter oldDelegate) {
    return oldDelegate.ringColor != ringColor ||
        oldDelegate.letterColor != letterColor ||
        oldDelegate.dotColor != dotColor;
  }
}
