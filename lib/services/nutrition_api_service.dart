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
      final url = Uri.parse("$_baseUrl?api_key=$_apiKey");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "query": query,
          "pageSize": 10
        }),
      );

      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List foods = data["foods"] ?? [];

        return foods.map((food) {
          double calories = 0;

          final nutrients = food["foodNutrients"] ?? [];
          for (var n in nutrients) {
            if (n["nutrientName"] == "Energy") {
              calories = (n["value"] ?? 0).toDouble();
              break;
            }
          }

          return {
            "name": food["description"],
            "calories": calories,
          };
        }).toList();
      }

      return [];
    } catch (e) {
      print("Error: $e");
      return [];
    }
  }
}