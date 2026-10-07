import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ⚙️ Replace with your backend IP and port
  static const String baseUrl = "http://192.168.1.34:8080";

  /// ✅ Generic POST request for reusability
  static Future<Map<String, dynamic>> postRequest(
      Uri url, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {
        "success": false,
        "message": "Error ${response.statusCode}: ${response.body}"
      };
    } catch (e) {
      return {"success": false, "message": "Network Error: $e"};
    }
  }

  /// 🔐 Login function
  static Future<Map<String, dynamic>> login(
      String email, String password) async {

    final url = Uri.parse("$baseUrl/api/auth/login");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email.trim(),
          "password": password.trim(),
        })

      );

      print("✅ STATUS CODE: ${response.statusCode}");
      print("✅ RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return {
          "success": true,
          "data": jsonDecode(response.body),
        };
      } else {
        return {
          "success": false,
          "message": response.body,
        };
      }
    } catch (e) {
      print("❌ NETWORK ERROR: $e");
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// 🔐 FORGOT PASSWORD – SEND OTP
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "message": "Network error: $e",
      };
    }
  }

  /// 🔐 VERIFY OTP
  static Future<Map<String, dynamic>> verifyOtp(
      String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "otp": otp.trim(),
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        "message": "Network error: $e",
      };
    }
  }

  /// 🔐 RESET PASSWORD
  static Future<Map<String, dynamic>> resetPassword(
      String resetToken, String newPassword) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "resetToken": resetToken,
          "newPassword": newPassword,
        }),
      );
      print(response.statusCode);
      print(response.body);


      return jsonDecode(response.body);
    } catch (e) {
      return {"message": "Something went wrong"};
    }
  }




  static Future<String> bookToken(int userId, String serviceName) async {
    final response = await http.post(
      Uri.parse("$baseUrl/token/book"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId, "serviceName": serviceName}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return "Token #${data['tokenNumber']} booked.\n"
          "Position: ${data['position']}\n"
          "Estimated time: ${data['estimatedTime']}";
    } else {
      return "Failed to book token.";
    }
  }

  static Future<List<Map<String, dynamic>>> getMyTokens(int userId) async {
    final response =
    await http.get(Uri.parse("$baseUrl/token/my-tokens/$userId"));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  static Future<Map<String, dynamic>> submitFeedback(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse("$baseUrl/feedback"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      return {"message": "Error: ${response.body}"};
    }
  }

  static Future<bool> requestSignupOtp(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup/requestOtp'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to send OTP');
    }

  }

  // ================= VERIFY SIGNUP OTP =================
  static Future<String> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup/verifyOtp'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'otp': otp,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['token']; // 👈 email verification token
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Invalid OTP');
    }
  }

  // ================= FINAL SIGNUP =================
  static Future<bool> signupUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String emailVerifiedToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/signup'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $emailVerifiedToken',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 201) {
      return true;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Signup failed');
    }
  }

  static Future<Map<String, String>> getAuthHeaders() async {

    final prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString("token");

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }
}






