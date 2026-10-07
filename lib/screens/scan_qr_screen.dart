import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:nextup/models/payment_model.dart';
import 'package:nextup/screens/QueueStatusScreen.dart';
import 'package:nextup/services/api_services.dart';
import 'package:nextup/services/payment_api.dart';
import 'package:nextup/services/razorpay_checkout.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PaymentMethod {
  cash,
  online,
  cancel,
}

class ScanQRScreen extends StatefulWidget {
  final int userId;



  const ScanQRScreen({super.key, required this.userId});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  bool _isProcessing = false;
  String? _lastScannedCode;



  final MobileScannerController _controller = MobileScannerController();

  final String baseUrl = "http://192.168.1.34:8080";

  Future<void> _joinQueue(String scannedValue) async {
    if (_isProcessing) return;
    if (_lastScannedCode == scannedValue) return;

    _lastScannedCode = scannedValue;

    int? serviceId = int.tryParse(scannedValue);

    if (serviceId == null) {
      _showSnackBar("Invalid QR Code");
      return;
    }

    setState(() => _isProcessing = true);
    _controller.stop();

    try {
      // 1. Ask the server whether this service charges a fee.
      final order = await PaymentApi.createOrder(serviceId);
      if (!mounted) return;

      Map<String, dynamic> data = {};

      if (order.paymentRequired) {
        // Show Cash / Online selection
        final method = await _selectPaymentMethod(order);

        if (!mounted) return;

        // User cancelled
        if (method == PaymentMethod.cancel) {
          await _resetScanner();
          return;
        }

        // =========================
        // CASH PAYMENT
        // =========================
        // =========================
// CASH PAYMENT
// =========================
        if (method == PaymentMethod.cash) {

          final response = await http
              .post(
            Uri.parse("$baseUrl/api/user/payment/cash"),
            headers: await ApiService.getAuthHeaders(),
            body: jsonEncode({
              "serviceId": serviceId,
            }),
          )
              .timeout(const Duration(seconds: 60));

          debugPrint("💵 CASH STATUS: ${response.statusCode}");
          debugPrint("💵 CASH BODY: ${response.body}");

          if (response.statusCode != 200) {
            throw PaymentApiException(
              response.statusCode,
              response.body.isNotEmpty
                  ? response.body
                  : "Cash payment failed",
            );
          }

          data = jsonDecode(response.body) as Map<String, dynamic>;
        }

        // =========================
        // ONLINE PAYMENT
        // =========================
        else if (method == PaymentMethod.online) {
          final result = await RazorpayCheckout.open(
            await _checkoutOptions(order),
          );

          if (!mounted) return;

          // Payment cancelled / failed
          if (!result.success ||
              result.orderId == null ||
              result.paymentId == null ||
              result.signature == null) {

            if (order.orderId != null) {
              await PaymentApi.reportFailure(
                order.orderId!,
                result.message ?? "Payment failed",
              );
            }

            _showSnackBar(
              result.cancelled
                  ? "Payment cancelled. You have not joined the queue."
                  : (result.message ?? "Payment failed. Please try again."),
            );

            await _resetScanner();
            return;
          }

          // Payment successful → verify → get token
          data = await _verifyWithRetry(result);
        }
      } else {
        // 2b. Free service: join directly, exactly as before.
        final response = await http
            .post(
          Uri.parse("$baseUrl/api/user/payment/cash"),
          headers: await ApiService.getAuthHeaders(),
          body: jsonEncode({
            "serviceId": serviceId,
          }),
        )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) {
          throw PaymentApiException(
              response.statusCode,
              response.body.isNotEmpty ? response.body : "Failed to join queue");
        }
        data = jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (!mounted) return;
      await _openQueueStatus(data, serviceId);
    } on PaymentApiException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
      await _resetScanner();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Server connection failed");
      await _resetScanner();
    }
  }

  /// Verification is idempotent on the server, so it is safe to retry after a network blip.
  /// The customer has already paid at this point, so we try hard before giving up.
  Future<Map<String, dynamic>> _verifyWithRetry(CheckoutResult result) async {
    Object? lastError;
    for (var attempt = 0; attempt < 4; attempt++) {
      try {
        return await PaymentApi.verify(
          orderId: result.orderId!,
          paymentId: result.paymentId!,
          signature: result.signature!,
        );
      } on PaymentApiException {
        rethrow; // the server answered: retrying will not change it
      } catch (e) {
        lastError = e; // network problem: wait and try again
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    throw PaymentApiException(
      0,
      "Payment received (ref ${result.paymentId}) but we could not confirm it. "
          "Check My Tokens in a moment or contact the service provider. ($lastError)",
    );
  }

  Future<Map<String, dynamic>> _checkoutOptions(PaymentOrder order) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email') ?? prefs.getString('userEmail');
    final phone = prefs.getString('phone') ?? prefs.getString('userPhone');

    return {
      'key': order.keyId,
      'amount': order.amountPaise,
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'NextUp',
      'description': order.serviceName,
      'timeout': 300, // seconds
      'theme': {'color': '#2563EB'},
      if ((email != null && email.isNotEmpty) || (phone != null && phone.isNotEmpty))
        'prefill': {
          if (email != null && email.isNotEmpty) 'email': email,
          if (phone != null && phone.isNotEmpty) 'contact': phone,
        },
    };
  }

  Future<PaymentMethod> _selectPaymentMethod(PaymentOrder order) async {
    final result = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Choose Payment Method",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                order.serviceName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                "₹${order.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 24),

              // Cash
              _paymentOption(
                context: ctx,
                icon: Icons.payments_outlined,
                title: "Pay Cash",
                subtitle: "Pay at the service counter",
                onTap: () {
                  Navigator.pop(ctx, PaymentMethod.cash);
                },
              ),

              const SizedBox(height: 12),

              // Online
              _paymentOption(
                context: ctx,
                icon: Icons.credit_card_outlined,
                title: "Pay Online",
                subtitle: "UPI, Card, Net Banking & more",
                onTap: () {
                  Navigator.pop(ctx, PaymentMethod.online);
                },
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  Navigator.pop(ctx, PaymentMethod.cancel);
                },
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? PaymentMethod.cancel;
  }

  Future<void> _resetScanner() async {
    _lastScannedCode = null; // allow scanning the same QR again
    if (mounted) setState(() => _isProcessing = false);
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _openQueueStatus(Map<String, dynamic> data, int serviceId) async {
    print("API RESPONSE: $data");

    // save avgWaitTime before navigating
    final prefs = await SharedPreferences.getInstance();
    final avgWait = (data["averageWaitingTimeMinutes"] as num?)?.toInt() ?? 0;
    await prefs.setInt('avgWaitTime', avgWait);
    debugPrint("💾 Saved avgWaitTime: $avgWait");

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QueueStatusScreen(
          serviceId: serviceId,
          serviceName: data["serviceName"] ?? "Service",
          tokenNumber: int.tryParse("${data["tokenNumber"]}") ?? 0,
          position: int.tryParse("${data["position"]}") ?? 0,
          estimatedTime: avgWait,
          status: data["status"] ?? "WAITING",
          queueEntryId: int.tryParse("${data["queueEntryId"]}") ?? 0,
          userId: int.tryParse("${data["userId"]}") ?? 0,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  Widget _paymentOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2563EB),
                size: 25,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [

            /// ===== HEADER =====
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Scan QR Code",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            /// ===== CAMERA FRAME CARD =====
            Expanded(
              child: Center(
                child: Transform.translate(
                  offset: const Offset(0, 40), // 👈 adjust this value
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: (capture) {
                          if (_isProcessing) return;

                          final barcode = capture.barcodes.first;
                          final code = barcode.rawValue;

                          if (code != null && code.isNotEmpty) {
                            _joinQueue(code);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            /// ===== INSTRUCTION =====
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                "Align the QR code inside the frame.\nScanning will start automatically.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
            ),

            const Spacer(),

            /// ===== LOADING OVERLAY =====
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: CircularProgressIndicator(),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
