class SleepScoreService {
  int calculateSleepScore({
    required int totalMinutes,
    required int deepMinutes,
    required int remMinutes,
    required int awakeMinutes,
    int targetMinutes = 480,
  }) {
    if (totalMinutes <= 0) return 0;

    final bool hasDeep = deepMinutes > 0;
    final bool hasRem = remMinutes > 0;
    final bool hasAwake = awakeMinutes > 0;

    double weightedScore = 0.0;
    double usedWeight = 0.0;

    final double durationPart;
    if (totalMinutes <= targetMinutes) {
      durationPart = (totalMinutes / targetMinutes) * 50.0;
    } else {
      final double over = (totalMinutes - targetMinutes) / targetMinutes;
      durationPart = (50.0 - over * 25.0).clamp(0.0, 50.0);
    }
    weightedScore += durationPart;
    usedWeight += 50.0;

    if (hasDeep) {
      final double deepRatio = deepMinutes / totalMinutes;
      const double idealDeepRatio = 0.18;
      final double deepPart =
          (20.0 - ((deepRatio - idealDeepRatio).abs() / idealDeepRatio) * 20.0)
              .clamp(0.0, 20.0);
      weightedScore += deepPart;
      usedWeight += 20.0;
    }

    if (hasRem) {
      final double remRatio = remMinutes / totalMinutes;
      const double idealRemRatio = 0.22;
      final double remPart =
          (20.0 - ((remRatio - idealRemRatio).abs() / idealRemRatio) * 20.0)
              .clamp(0.0, 20.0);
      weightedScore += remPart;
      usedWeight += 20.0;
    }

    if (hasAwake) {
      final double awakeRatio = awakeMinutes / totalMinutes;
      final double awakePart = (10.0 - (awakeRatio * 40.0)).clamp(0.0, 10.0);
      weightedScore += awakePart;
      usedWeight += 10.0;
    }

    if (usedWeight <= 0) return 0;
    return ((weightedScore / usedWeight) * 100.0).round().clamp(0, 100);
  }
}
