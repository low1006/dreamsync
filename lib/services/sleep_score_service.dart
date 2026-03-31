import 'package:flutter/foundation.dart';

class SleepScoreService {
  static const double idealDeepRatio = 0.18;
  static const double idealRemRatio = 0.22;
  static const int targetMinutes = 480; // 8h

  int calculateSleepScore({
    required int totalMinutes,
    required int deepMinutes,
    required int remMinutes,
    required int awakeMinutes,
    int targetMinutes = 480,
  }) {
    if (totalMinutes <= 0) {
      debugPrint('💤 SleepScore => totalMinutes <= 0, score=0');
      return 0;
    }

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

    double deepPart = 0.0;
    double remPart = 0.0;
    double awakePart = 0.0;

    if (hasDeep) {
      final double deepRatio = deepMinutes / totalMinutes;
      deepPart =
          (20.0 - ((deepRatio - idealDeepRatio).abs() / idealDeepRatio) * 20.0)
              .clamp(0.0, 20.0);
      weightedScore += deepPart;
      usedWeight += 20.0;
    }

    if (hasRem) {
      final double remRatio = remMinutes / totalMinutes;
      remPart =
          (20.0 - ((remRatio - idealRemRatio).abs() / idealRemRatio) * 20.0)
              .clamp(0.0, 20.0);
      weightedScore += remPart;
      usedWeight += 20.0;
    }

    if (hasAwake) {
      final double awakeRatio = awakeMinutes / totalMinutes;
      awakePart = (10.0 - (awakeRatio * 40.0)).clamp(0.0, 10.0);
      weightedScore += awakePart;
      usedWeight += 10.0;
    }

    if (usedWeight <= 0) {
      debugPrint('💤 SleepScore => usedWeight <= 0, score=0');
      return 0;
    }

    final score = ((weightedScore / usedWeight) * 100.0).round().clamp(0, 100);

    debugPrint(
      '📊 SleepScore calculation => '
          'total=${totalMinutes}m (${(totalMinutes / 60).toStringAsFixed(2)}h), '
          'deep=${deepMinutes}m, rem=${remMinutes}m, awake=${awakeMinutes}m | '
          'durationPart=${durationPart.toStringAsFixed(2)}, '
          'deepPart=${deepPart.toStringAsFixed(2)}, '
          'remPart=${remPart.toStringAsFixed(2)}, '
          'awakePart=${awakePart.toStringAsFixed(2)} | '
          'usedWeight=${usedWeight.toStringAsFixed(2)} | '
          'weightedScore=${weightedScore.toStringAsFixed(2)} | '
          'finalScore=$score',
    );

    return score;
  }
}