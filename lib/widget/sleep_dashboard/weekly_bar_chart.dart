import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.only(top: 20, right: 8, left: 8, bottom: 12),
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
            width: 32,
            height: 130,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatValue(calculatedMax) + unit,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  _formatValue(calculatedMax / 2) + unit,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  "0$unit",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 130,
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.black26, width: 2),
                      bottom: BorderSide(color: Colors.black26, width: 2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(values.length, (index) {
                      double heightFactor = values[index] / calculatedMax;
                      bool isToday = index == values.length - 1;

                      return SizedBox(
                        width: 32,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              values[index] > 0 ? _formatValue(values[index]) : "0",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isToday ? color : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: values[index] == 0 ? 2 : 110 * heightFactor,
                              width: 20,
                              decoration: BoxDecoration(
                                color: values[index] == 0
                                    ? Colors.grey.shade300
                                    : (isToday ? color : color.withOpacity(0.4)),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(labels.length, (index) {
                      bool isToday = index == labels.length - 1;
                      return SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight:
                              isToday ? FontWeight.bold : FontWeight.w500,
                              color:
                              isToday ? Colors.black87 : Colors.grey.shade600,
                            ),
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double val) {
    if (val == 0) return "0";
    if (isDecimal) return val.toStringAsFixed(1);
    return val.toInt().toString();
  }
}