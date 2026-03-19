import 'package:flutter/material.dart';
import 'dart:math' as math;

class SleepScoreGaugePainter extends CustomPainter {
  final int score;
  final Color themeColor;

  SleepScoreGaugePainter({required this.score, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;
    const double strokeWidth = 14.0;

    const double startAngle = math.pi * 0.8;
    const double sweepAngle = math.pi * 1.4;

    final Offset center = Offset(centerX, centerY);
    final Rect rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paintTrack = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paintTrack);

    final double scoreSweepAngle = (score / 100) * sweepAngle;
    final paintProgress = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, scoreSweepAngle, false, paintProgress);

    final textPainterScore = TextPainter(
      text: TextSpan(
        text: score.toString(),
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterScore.layout();
    textPainterScore.paint(
      canvas,
      Offset(centerX - textPainterScore.width / 2, centerY - 20),
    );

    final textPainterLabel = TextPainter(
      text: const TextSpan(
        text: "Sleep Score",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterLabel.layout();
    textPainterLabel.paint(
      canvas,
      Offset(centerX - textPainterLabel.width / 2, centerY + textPainterScore.height - 20),
    );

    const textStyleNumbers = TextStyle(fontSize: 10, color: Colors.grey);
    final textPainterZero = TextPainter(
      text: const TextSpan(text: "0", style: textStyleNumbers),
      textDirection: TextDirection.ltr,
    )..layout();

    final textPainterHundred = TextPainter(
      text: const TextSpan(text: "100", style: textStyleNumbers),
      textDirection: TextDirection.ltr,
    )..layout();

    final double sinStart = math.sin(startAngle);
    final double cosStart = math.cos(startAngle);
    final double sinEnd = math.sin(startAngle + sweepAngle);
    final double cosEnd = math.cos(startAngle + sweepAngle);

    textPainterZero.paint(
      canvas,
      Offset(centerX + (radius) * cosStart - 5, centerY + (radius) * sinStart + 10),
    );

    textPainterHundred.paint(
      canvas,
      Offset(centerX + (radius) * cosEnd - 15, centerY + (radius) * sinEnd + 10),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}