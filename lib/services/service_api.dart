import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service_model.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service_model.dart';

class ServiceApi {

  static const String baseUrl = "https://nextup-backend-zlou.onrender.com/api/provider";

  static Future<List<ServiceModel>> getServices(
      int providerId,
      String token,
      ) async {

    final response = await http.get(
      Uri.parse("$baseUrl/services/$providerId"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {

      final List data = jsonDecode(response.body);

      return data
          .map((e) => ServiceModel.fromJson(e))
          .toList();

    } else {

      throw Exception("Failed to load services");
    }
  }

  static Future<ServiceModel> createService(
      Map<String, dynamic> body, String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/services"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return ServiceModel.fromJson(jsonDecode(response.body));
    } else {
      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      throw Exception(response.body);
    }
  }

  static Future<void> deleteService(int serviceId) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/$serviceId"),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception("Failed to delete service");
    }
  }
}