class TimeFormatter {
  static String formatHours(double hours) {
    if (hours <= 0) return "0h 0m";

    int h = hours.floor();
    int m = ((hours - h) * 60).round();

    if (m == 60) {
      h += 1;
      m = 0;
    }

    return "${h}h ${m}m";
  }

  static String formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return "0h 0m";

    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return "${h}h ${m}m";
  }

  static String formatClockHour(double hour) {
    int totalMinutes = (hour * 60).round();
    int h = (totalMinutes ~/ 60) % 24;
    int m = totalMinutes % 60;

    if (h < 0) h += 24;

    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  static String formatByUnit(double value, String unit) {
    if (unit == 'h') {
      return formatHours(value);
    }

    if (unit == 'm') {
      return "${value.round()}m";
    }

    if (unit == 'k') {
      return "${value.round()}";
    }

    return value.round().toString();
  }

  static String formatZeroByUnit(String unit) {
    if (unit == 'h') return "0h 0m";
    if (unit == 'm') return "0m";
    if (unit == 'k') return "0";
    return "0";
  }
}