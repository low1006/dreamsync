enum MoodFeedback {
  sad,
  neutral,
  happy,
}

extension MoodFeedbackX on MoodFeedback {
  String get value {
    switch (this) {
      case MoodFeedback.sad:
        return 'sad';
      case MoodFeedback.neutral:
        return 'neutral';
      case MoodFeedback.happy:
        return 'happy';
    }
  }

  String get label {
    switch (this) {
      case MoodFeedback.sad:
        return 'Sad';
      case MoodFeedback.neutral:
        return 'Neutral';
      case MoodFeedback.happy:
        return 'Happy';
    }
  }

  static MoodFeedback? fromValue(String? value) {
    switch (value?.toLowerCase()) {
      case 'sad':
        return MoodFeedback.sad;
      case 'neutral':
        return MoodFeedback.neutral;
      case 'happy':
        return MoodFeedback.happy;
      default:
        return null;
    }
  }
}