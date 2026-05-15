import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = "https://nextup-backend-zlou.onrender.com"; // Android emulator → your backend

  Future<bool> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/api/auth/login");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      // TODO: Extract and save JWT token later
      return true;
    } else {
      return false;
    }
  }
}
