import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ExerciseApiService {
  static final String _apiKey =
      dotenv.env['EXERCISE_API_KEY'] ?? '';

  static final String _baseUrl =
      dotenv.env['EXERCISE_API_URL'] ??
          'https://api.api-ninjas.com/v1/caloriesburned';

  /// Searches exercises by name and returns a list of exercises
  /// with calories burned per hour for a given weight.
  ///
  /// Each result contains:
  /// - "name": exercise name
  /// - "calories_per_hour": calories burned per hour
  /// - "duration_minutes": default 60
  /// - "total_calories": calories for [durationMinutes] at [weightKg]
  static Future<List<Map<String, dynamic>>> searchExercises(
      String query, {
        double? weightKg,
        int durationMinutes = 60,
      }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'activity': query,
      };

      // API Ninjas supports weight in lbs
      if (weightKg != null && weightKg > 0) {
        final weightLbs = (weightKg * 2.20462).round();
        queryParams['weight'] = weightLbs.toString();
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'X-Api-Key': _apiKey,
          'Content-Type': 'application/json',
        },
      );

      print("Exercise API Status: ${response.statusCode}");
      print("Exercise API Body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        return data.map((exercise) {
          final caloriesPerHour =
          (exercise['calories_per_hour'] ?? 0).toDouble();

          // Calculate calories for the requested duration
          final totalCalories =
          (caloriesPerHour * durationMinutes / 60).round();

          return {
            'name': _cleanExerciseName(exercise['name'] ?? 'Unknown Exercise'),
            'calories_per_hour': caloriesPerHour,
            'duration_minutes': exercise['duration_minutes'] ?? durationMinutes,
            'total_calories': exercise['total_calories'] ?? totalCalories,
          };
        }).toList();
      }

      return [];
    } catch (e) {
      print("Exercise API Error: $e");
      return [];
    }
  }

  /// Cleans up verbose API exercise names for display.
  ///
  /// Examples:
  ///   "Running, 5 mph (12 minute mile)" → "Running — 8.0 km/h"
  ///   "Bicycling, 12-13.9 mph, moderate" → "Bicycling — 19.3-22.4 km/h, Moderate"
  ///   "Swimming laps, freestyle, light" → "Swimming Laps, Freestyle, Light"
  static String _cleanExerciseName(String raw) {
    String name = raw.trim();

    // 1. Remove parenthetical pace info like "(12 minute mile)"
    name = name.replaceAll(RegExp(r'\s*\([^)]*minute[^)]*\)'), '');

    // 2. Convert mph speeds to km/h
    // Matches patterns like "5 mph" or "12-13.9 mph"
    name = name.replaceAllMapped(
      RegExp(r'(\d+\.?\d*)\s*-?\s*(\d+\.?\d*)?\s*mph', caseSensitive: false),
          (match) {
        final low = double.tryParse(match.group(1) ?? '') ?? 0;
        final highStr = match.group(2);

        if (highStr != null && highStr.isNotEmpty) {
          final high = double.tryParse(highStr) ?? 0;
          final lowKmh = (low * 1.60934).toStringAsFixed(1);
          final highKmh = (high * 1.60934).toStringAsFixed(1);
          return '$lowKmh–$highKmh km/h';
        } else {
          final kmh = (low * 1.60934).toStringAsFixed(1);
          return '$kmh km/h';
        }
      },
    );

    // 3. Replace first comma with " —" for cleaner separation
    //    e.g. "Running, 8.0 km/h" → "Running — 8.0 km/h"
    final commaIndex = name.indexOf(',');
    if (commaIndex != -1) {
      name = '${name.substring(0, commaIndex)} —${name.substring(commaIndex + 1)}';
    }

    // 4. Clean up extra whitespace
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // 5. Title-case first letter of each segment
    name = name.split(' — ').map((segment) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) return trimmed;
      return trimmed[0].toUpperCase() + trimmed.substring(1);
    }).join(' — ');

    return name;
  }

  /// Calculates estimated calories burned for a given exercise.
  ///
  /// [caloriesPerHour] — the base rate from the API
  /// [durationMinutes] — how long the user exercised
  /// [weightKg] — optional user weight for more accurate estimates
  static int calculateCaloriesBurned({
    required double caloriesPerHour,
    required int durationMinutes,
  }) {
    return (caloriesPerHour * durationMinutes / 60).round();
  }
}