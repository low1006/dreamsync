import 'package:flutter/material.dart';
import 'package:dreamsync/util/time_formatter.dart';
import 'package:dreamsync/util/app_theme.dart';

class WeeklyBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String unit;
  final Color color;
  final double maxY;
  final bool isDecimal;

  const WeeklyBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.unit = "",
    this.color = AppTheme.accent,
    this.maxY = 0,
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    double calculatedMax =
    values.fold(maxY, (prev, element) => element > prev ? element : prev);

    if (calculatedMax == 0) calculatedMax = 1;

    // Resolve theme-aware colors once for the whole widget.
    final Color axisColor = AppTheme.border(context);
    final Color subTextColor = AppTheme.subText(context);
    final Color textColor = AppTheme.text(context);
    final Color emptyBarColor = AppTheme.isDark(context)
        ? Colors.white.withOpacity(0.12)
        : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 10),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Y-axis labels ──────────────────────────────────────
          SizedBox(
            width: 42,
            height: 126,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatAxisValue(calculatedMax),
                    style: TextStyle(fontSize: 8, color: subTextColor),
                    maxLines: 1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatAxisValue(calculatedMax / 2),
                    style: TextStyle(fontSize: 8, color: subTextColor),
                    maxLines: 1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatAxisValue(0),
                    style: TextStyle(fontSize: 8, color: subTextColor),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // ── Bars + X-axis labels ───────────────────────────────
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 126,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: axisColor, width: 1.5),
                      bottom: BorderSide(color: axisColor, width: 1.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(values.length, (index) {
                      final double heightFactor =
                      (values[index] / calculatedMax).clamp(0.0, 1.0);
                      final bool isToday = index == values.length - 1;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Value label above bar
                              SizedBox(
                                height: 24,
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      values[index] > 0
                                          ? _formatBarValue(values[index])
                                          : TimeFormatter.formatZeroByUnit(unit),
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color: isToday ? color : subTextColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Bar itself
                              Container(
                                height: values[index] == 0 ? 2 : 94 * heightFactor,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: values[index] == 0
                                      ? emptyBarColor
                                      : (isToday ? color : color.withOpacity(0.4)),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 6),

                // ── Day labels ─────────────────────────────────────
                Row(
                  children: List.generate(labels.length, (index) {
                    final bool isToday = index == labels.length - 1;
                    return Expanded(
                      child: Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                          color: isToday ? textColor : subTextColor,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAxisValue(double val) {
    return TimeFormatter.formatByUnit(val, unit);
  }

  String _formatBarValue(double val) {
    return TimeFormatter.formatByUnit(val, unit);
  }
}
