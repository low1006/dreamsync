import 'package:flutter/material.dart';
import 'package:dreamsync/models/sleep_model/sleep_chart_point.dart';
import 'package:dreamsync/util/time_formatter.dart';

class HypnogramPainter extends CustomPainter {
  final List<SleepChartPoint> data;

  static const _stageColors = {
    3: Color(0xFFFF7043), // Awake
    2: Color(0xFF9C64FF), // REM
    1: Color(0xFF42A5F5), // Light
    0: Color(0xFF1A237E), // Deep
  };

  static const _stageLabels = {3: "Awake", 2: "REM", 1: "Light", 0: "Deep"};

  static const double _labelWidth = 42.0;
  static const double _timeHeight = 24.0;
  static const double _topPad = 4.0;
  static const int _stageCount = 4;

  HypnogramPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final double chartLeft = _labelWidth;
    final double chartRight = size.width - 6;
    final double chartTop = _topPad;
    final double chartBottom = size.height - _timeHeight;
    final double chartH = chartBottom - chartTop;
    final double chartW = chartRight - chartLeft;
    final double stageH = chartH / _stageCount;

    final double minHour = data.isEmpty ? 0.0 : data.first.hour;
    final double maxHour = data.isEmpty ? 8.0 : data.last.hour;
    final double hourSpan = (maxHour - minHour) == 0 ? 1 : (maxHour - minHour);

    double toX(double hour) =>
        chartLeft + (hour - minHour) / hourSpan * chartW;
    double toY(int stage) => chartTop + (3 - stage) * stageH;

    final dividerPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;

    for (int s = 0; s <= _stageCount; s++) {
      final double y = chartTop + s * stageH;
      canvas.drawLine(
        Offset(chartLeft, y),
        Offset(chartRight, y),
        dividerPaint,
      );
    }

    for (int s = 0; s < _stageCount; s++) {
      final double y = chartTop + (3 - s) * stageH + stageH / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: _stageLabels[s],
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _stageColors[s]!,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _labelWidth - 4);

      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final timeLabelStyle = const TextStyle(fontSize: 9, color: Colors.grey);
    final int labelCount = (chartW ~/ 70).clamp(3, 6);

    for (int i = 0; i <= labelCount; i++) {
      final double hour = minHour + (hourSpan / labelCount) * i;
      final double x = toX(hour);

      final String label = TimeFormatter.formatClockHour(hour);

      final tp = TextPainter(
        text: TextSpan(text: label, style: timeLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final double safeX = (x - tp.width / 2).clamp(chartLeft, chartRight - tp.width);
      tp.paint(canvas, Offset(safeX, chartBottom + 4));
    }

    if (data.isEmpty) return;

    for (int i = 0; i < data.length - 1; i++) {
      final SleepChartPoint cur = data[i];
      final SleepChartPoint next = data[i + 1];

      final int stage = cur.stage.round().clamp(0, 3);
      final Color color = _stageColors[stage] ?? Colors.grey;

      final double x1 = toX(cur.hour);
      final double x2 = toX(next.hour);
      final double y1 = toY(stage);
      final double y2 = y1 + stageH;

      final blockPaint = Paint()..color = color.withOpacity(0.85);
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), blockPaint);

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y1), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant HypnogramPainter oldDelegate) =>
      oldDelegate.data != data;
}