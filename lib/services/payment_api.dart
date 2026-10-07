import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/payment_model.dart';
import 'api_services.dart';

/// The server rejected the request (as opposed to a network failure).
class PaymentApiException implements Exception {
  final int statusCode;
  final String message;
  PaymentApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

/// Talks to the NextUp backend's Razorpay endpoints.
/// The amount is never sent from the app: the server reads the fee from the service.
class PaymentApi {
  static const Duration _timeout = Duration(seconds: 60); // free hosting can cold-start

  static String get _base => ApiService.baseUrl;

  static String _errorText(http.Response r) {
    final body = r.body.trim();
    if (body.isEmpty) return 'Request failed (${r.statusCode})';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return body;
  }

  /// Step 1 – ask the server for a Razorpay order (or learn the service is free).
  static Future<PaymentOrder> createOrder(int serviceId) async {
    final r = await http
        .post(
      Uri.parse('$_base/api/user/payment/create-order'),
      headers: await ApiService.getAuthHeaders(),
      body: jsonEncode({'serviceId': serviceId}),
    )
        .timeout(_timeout);

    if (r.statusCode != 200) throw PaymentApiException(r.statusCode, _errorText(r));
    return PaymentOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// Step 3 – hand Razorpay's result to the server. On success it issues the queue token
  /// and returns the same JSON a normal join returns.
  static Future<Map<String, dynamic>> verify({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    final r = await http
        .post(
      Uri.parse('$_base/api/user/payment/verify'),
      headers: await ApiService.getAuthHeaders(),
      body: jsonEncode({
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      }),
    )
        .timeout(_timeout);

    if (r.statusCode != 200) throw PaymentApiException(r.statusCode, _errorText(r));
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Tell the server the checkout failed or was dismissed (best effort).
  static Future<void> reportFailure(String orderId, String reason) async {
    try {
      await http
          .post(
        Uri.parse('$_base/api/user/payment/failed'),
        headers: await ApiService.getAuthHeaders(),
        body: jsonEncode({'razorpayOrderId': orderId, 'reason': reason}),
      )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // not critical: the order simply stays PENDING
    }
  }

  static Future<List<PaymentRecord>> myPayments() async {
    final r = await http
        .get(Uri.parse('$_base/api/user/payment/history'),
        headers: await ApiService.getAuthHeaders())
        .timeout(_timeout);
    if (r.statusCode != 200) throw PaymentApiException(r.statusCode, _errorText(r));
    final list = jsonDecode(r.body) as List;
    return list.map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<PaymentRecord>> providerPayments(int providerId) async {
    final r = await http
        .get(Uri.parse('$_base/api/payments/provider/$providerId'),
        headers: await ApiService.getAuthHeaders())
        .timeout(_timeout);
    if (r.statusCode != 200) throw PaymentApiException(r.statusCode, _errorText(r));
    final list = jsonDecode(r.body) as List;
    return list.map((e) => PaymentRecord.fromJson(e as Map<String, dynamic>)).toList();
  }
}
