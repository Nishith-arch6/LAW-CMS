import 'package:flutter/material.dart';

class CourtPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 48.0;
    final columnPaint = Paint()
      ..color = const Color(0xFFC9A84C).withAlpha(6)
      ..strokeWidth = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), columnPaint);
    }

    final vignette = RadialGradient(
      colors: [
        Colors.transparent,
        const Color(0xFF1A0F0A).withAlpha(120),
      ],
      radius: 0.9,
      focal: const Alignment(0.0, -0.3),
    );
    final vignettePaint = Paint()..shader = vignette.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    final arcPaint = Paint()
      ..color = const Color(0xFFC9A84C).withAlpha(8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final centerX = size.width / 2;
    final topY = size.height * 0.15;
    final archWidth = size.width * 0.4;
    final archHeight = size.height * 0.25;

    final archPath = Path()
      ..moveTo(centerX - archWidth / 2, topY + archHeight)
      ..quadraticBezierTo(
        centerX - archWidth / 2,
        topY,
        centerX,
        topY,
      )
      ..quadraticBezierTo(
        centerX + archWidth / 2,
        topY,
        centerX + archWidth / 2,
        topY + archHeight,
      );
    canvas.drawPath(archPath, arcPaint);

    final innerArchPath = Path()
      ..moveTo(centerX - archWidth / 3, topY + archHeight * 0.8)
      ..quadraticBezierTo(
        centerX - archWidth / 3,
        topY + archHeight * 0.2,
        centerX,
        topY + archHeight * 0.2,
      )
      ..quadraticBezierTo(
        centerX + archWidth / 3,
        topY + archHeight * 0.2,
        centerX + archWidth / 3,
        topY + archHeight * 0.8,
      );
    canvas.drawPath(innerArchPath, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
