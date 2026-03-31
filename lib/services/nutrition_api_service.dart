import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NutritionApiService {
  static final String _apiKey =
      dotenv.env['NUTRITION_API_KEY'] ?? '';

  static final String _baseUrl =
      dotenv.env['NUTRITION_API_URL'] ?? '';

  static Future<List<Map<String, dynamic>>> searchFoods(String query) async {
    try {
      // Try Foundation + Survey first (clean, general entries)
      var results = await _fetchFromUSDA(
        query,
        dataTypes: ["Foundation", "Survey (FNDDS)"],
      );

      // Fallback to Branded if no results (local/packaged foods)
      if (results.isEmpty) {
        results = await _fetchFromUSDA(
          query,
          dataTypes: ["Branded"],
        );
      }

      return results;
    } catch (e) {
      print("Error: $e");
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchFromUSDA(
      String query, {
        required List<String> dataTypes,
      }) async {
    final url = Uri.parse("$_baseUrl?api_key=$_apiKey");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "query": query,
        "pageSize": 25,
        "dataType": dataTypes,
      }),
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final List foods = data["foods"] ?? [];

    final List<Map<String, dynamic>> results = [];
    final Set<String> seenNames = {};

    for (final food in foods) {
      double calories = 0;
      double caffeineMg = 0;
      double sugarG = 0;
      double alcoholG = 0;

      final nutrients = food["foodNutrients"] ?? [];
      for (var n in nutrients) {
        final name = (n["nutrientName"] ?? "").toString();

        if (name == "Energy") {
          calories = (n["value"] ?? 0).toDouble();
        } else if (name == "Caffeine") {
          caffeineMg = (n["value"] ?? 0).toDouble();
        } else if (name.contains("Sugars, total") || name == "Total Sugars") {
          sugarG = (n["value"] ?? 0).toDouble();
        } else if (name == "Alcohol, ethyl") {
          alcoholG = (n["value"] ?? 0).toDouble();
        }
      }

      final rawName = (food["description"] ?? "Unknown").toString();
      final cleanName = _cleanFoodName(rawName);

      // Deduplicate by normalized name
      final key = cleanName.toLowerCase();
      if (seenNames.contains(key)) continue;
      seenNames.add(key);

      results.add({
        "name": cleanName,
        "calories": calories,
        "caffeine_mg": caffeineMg,
        "sugar_g": sugarG,
        "alcohol_g": alcoholG,
      });

      // Cap at 10 unique results
      if (results.length >= 10) break;
    }

    return results;
  }

  /// Cleans up USDA food names for display.
  static String _cleanFoodName(String raw) {
    String name = raw.trim();

    // Title-case if the name is mostly uppercase
    if (name == name.toUpperCase()) {
      name = name
          .split(' ')
          .map((word) {
        if (word.isEmpty) return word;
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      })
          .join(' ');
    }

    return name;
  }
}