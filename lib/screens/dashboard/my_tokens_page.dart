import 'package:flutter/material.dart';
import 'package:nextup/screens/QueueStatusScreen.dart';
import '../../services/api_services.dart';
import '../../widgets/token_card.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:nextup/services/notification_service.dart';

class MyTokensPage extends StatefulWidget {
  final int userId;

  const MyTokensPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyTokensPage> createState() => _MyTokensPageState();
}

class _MyTokensPageState extends State<MyTokensPage> {
  List<dynamic> myQueues = [];
  bool isLoading = true;
  Timer? _timer;

  final String baseUrl = "https://nextup-backend-production-42bf.up.railway.app";

  @override
  void initState() {
    super.initState();
    _fetchTokens();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
          (_) => _fetchTokens(),
    );
  }

  Future<void> _fetchTokens() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/queue/user/${widget.userId}"),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          myQueues = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3730A3), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "My Tokens",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      myQueues.isEmpty
                          ? "No active queues"
                          : "${myQueues.length} active queue${myQueues.length > 1 ? 's' : ''}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            )
                : myQueues.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              color: const Color(0xFF6366F1),
              onRefresh: _fetchTokens,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                itemCount: myQueues.length,
                itemBuilder: (context, index) {
                  return _buildTokenCard(myQueues[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Token Card ───────────────────────────────────────────────────────────
  Widget _buildTokenCard(dynamic queue) {
    final bool isNext = queue["position"] == 1;

    return GestureDetector(
      onTap: () {
        print(queue);

        final qId = queue["id"];
        final uId = queue["userId"] ?? widget.userId; // ✅ fallback to widget.userId
        print("🔍 QUEUE DATA: $queue");
        print("🔍 qId: $qId, uId: $uId");
        if (qId == null || uId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid token data")),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QueueStatusScreen(
              serviceId: queue["serviceId"],
              serviceName: queue["serviceName"] ?? "Service",
              tokenNumber: queue["tokenNumber"] ?? 0,
              position: queue["position"] ?? 0,
              estimatedTime: queue["averageWaitingTimeMinutes"] ?? 0,
              status: queue["status"] ?? "WAITING",
              queueEntryId: qId,
              userId: uId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Colored top bar ────────────────────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isNext
                      ? [const Color(0xFF16A34A), const Color(0xFF4ADE80)]
                      : [const Color(0xFF4F46E5), const Color(0xFF818CF8)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Service name + badge ───────────────────────
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isNext
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.confirmation_number_outlined,
                          size: 18,
                          color: isNext
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          queue["serviceName"] ?? "Service",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      _statusBadge(isNext),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Token highlight (original layout kept) ─────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Tap hint
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Tap to see live queue updates",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        // Token number
                        Row(
                          children: [
                            Text(
                              "Your Token  ",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade400,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              "#${queue["tokenNumber"]}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isNext
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF4F46E5),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status badge ─────────────────────────────────────────────────────────
  Widget _statusBadge(bool isNext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isNext
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isNext ? "You're Next!" : "Active",
        style: TextStyle(
          color: isNext ? const Color(0xFF16A34A) : const Color(0xFF4F46E5),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // ── Empty state ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              size: 36,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "No Active Tokens",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Scan a QR code to join a queue",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoItem(IconData icon, String title, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: Colors.grey.shade700),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}