import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:nextup/screens/QueueStatusScreen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  final String baseUrl = "https://nextup-backend-production-42bf.up.railway.app";

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
      // ✅ Correct endpoint
      final response = await http.post(
        Uri.parse("$baseUrl/api/queue/join"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": widget.userId,
          "serviceId": serviceId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print("API RESPONSE: $data");

        // ✅ ADD THIS — save avgWaitTime before navigating
        final prefs = await SharedPreferences.getInstance();
        final avgWait = (data["averageWaitingTimeMinutes"] as num?)?.toInt() ?? 0;
        await prefs.setInt('avgWaitTime', avgWait);
        debugPrint("💾 Saved avgWaitTime: $avgWait");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QueueStatusScreen(
              serviceId: serviceId,
              serviceName: data["serviceName"] ?? "Service",
              tokenNumber: int.tryParse("${data["tokenNumber"]}") ?? 0,
              position: int.tryParse("${data["position"]}") ?? 0,
              estimatedTime: avgWait, // ✅ reuse avgWait directly
              status: data["status"] ?? "WAITING",
              queueEntryId: int.tryParse("${data["queueEntryId"]}") ?? 0,
              userId: int.tryParse("${data["userId"]}") ?? 0,
            ),
          ),
        );

      } else {
        _showSnackBar("Failed to join queue");
        _controller.start();
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      _showSnackBar("Server connection failed");
      _controller.start();
      setState(() => _isProcessing = false);
    }
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
