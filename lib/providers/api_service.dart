import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String loginUrl = "https://tab.itec.rw/android_access/login";

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse(loginUrl);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print("API Request: POST $loginUrl");
      print("Request Body: ${jsonEncode({
            'email': email,
            'password': password
          })}");
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'Invalid credentials'};
      }
    } catch (e) {
      print("API Error: $e");
      return {'error': 'Something went wrong: $e'};
    }
  }
}
