import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiClient {
  static Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      print("POST => $endpoint");
      print("BODY => $body");

      final response = await http
          .post(
            Uri.parse("${AppConfig.baseUrl}$endpoint"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      print("STATUS => ${response.statusCode}");
      print("RESPONSE => ${response.body}");

      if (response.statusCode != 200) {
        return {"error": "Server error"};
      }

      return jsonDecode(response.body);
    } catch (e) {
      print("API ERROR => $e");

      return {"error": e.toString()};
    }
  }

  static Future<dynamic> get(String endpoint) async {
    try {
      print("GET => $endpoint");

      final response = await http
          .get(Uri.parse("${AppConfig.baseUrl}$endpoint"))
          .timeout(const Duration(seconds: 60));

      print("STATUS => ${response.statusCode}");
      print("RESPONSE => ${response.body}");

      if (response.statusCode != 200) {
        return {"error": "Server error"};
      }

      return jsonDecode(response.body);
    } catch (e) {
      print("API ERROR => $e");

      return {"error": e.toString()};
    }
  }
}
