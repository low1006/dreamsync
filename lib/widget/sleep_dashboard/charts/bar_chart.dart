import 'package:flutter/material.dart';
import 'package:dreamsync/util/time_formatter.dart';

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
    this.color = Colors.indigoAccent,
    this.maxY = 0,
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) {
    double calculatedMax =
    values.fold(maxY, (prev, element) => element > prev ? element : prev);

    if (calculatedMax == 0) calculatedMax = 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    maxLines: 1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatAxisValue(calculatedMax / 2),
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    maxLines: 1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _formatAxisValue(0),
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 126,
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.black26, width: 1.5),
                      bottom: BorderSide(color: Colors.black26, width: 1.5),
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
                                        color: isToday
                                            ? color
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height:
                                values[index] == 0 ? 2 : 94 * heightFactor,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: values[index] == 0
                                      ? Colors.grey.shade300
                                      : (isToday
                                      ? color
                                      : color.withOpacity(0.4)),
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
                          fontWeight:
                          isToday ? FontWeight.bold : FontWeight.w500,
                          color:
                          isToday ? Colors.black87 : Colors.grey.shade600,
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