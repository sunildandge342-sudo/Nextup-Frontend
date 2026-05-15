import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:nextup/services/background_service.dart';
import 'package:nextup/services/notification_service.dart';
import 'package:nextup/services/notifications_store.dart';
import 'package:shared_preferences/shared_preferences.dart';


class QueueStatusScreen extends StatefulWidget {
  final String serviceName;
  final int tokenNumber;
  final int position;
  final int estimatedTime;
  final dynamic status;
  final int queueEntryId;
  final int userId;
  final int serviceId;

  const QueueStatusScreen({
    super.key,
    required this.serviceName,
    required this.tokenNumber,
    required this.position,
    required this.estimatedTime,
    required this.status,
    required this.queueEntryId,
    required this.userId,
    required this.serviceId,

  });

  @override
  State<QueueStatusScreen> createState() => _QueueStatusScreenState();
}

class _QueueStatusScreenState extends State<QueueStatusScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  Timer? _pollingTimer;

  bool get isNext => _position == 1 && _status == "WAITING";
  bool get isProcessing => _status == "SERVING";

  int _position = 0;
  int _estimatedTime = 0;
  String _status = "";
  bool notificationSent = false;
  int? _lastPosition;
  bool notifiedFor3 = false;
  bool notifiedFor1 = false;
  int? _previousPosition;


  // ── Start background tracking ────────────────────────────────────────────
  // ── Start background tracking ──────────────────────────────────────────
  Future<void> _startBackgroundTracking() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    // Stop any existing session before starting a new one
    if (isRunning) {
      service.invoke('stopTracking');
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await service.startService();

    // Small delay to let the service initialize before sending the event
    await Future.delayed(const Duration(milliseconds: 500));

    service.invoke('startTracking', {
      'serviceName': widget.serviceName,
      'userId': widget.userId,
      'currentPosition': widget.position,
    });

    debugPrint("Background tracking started");
  }

// ── Stop background tracking ───────────────────────────────────────────
  Future<void> _stopBackgroundTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stopTracking');
  }

  // ── Cancel token ────────────────────────────────────────────────────────
  Future<void> cancelToken() async {
    print("QUEUE ENTRY ID: ${widget.queueEntryId}");
    print("USER ID: ${widget.userId}");

    final url = Uri.parse(
        "https://nextup-backend-zlou.onrender.com/api/user/cancel/${widget.queueEntryId}?userId=${widget.userId}");

    final response = await http.delete(url);

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (!mounted) return;

    if (response.statusCode == 200) {
      await _stopBackgroundTracking(); // ✅ Stop tracking on cancel
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Token cancelled"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed (${response.statusCode})"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ── Load queue status ────────────────────────────────────────────────────
  bool _isDialogShown = false; // add this at class level

  Future<void> _loadQueueStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId');

      if (userId == null || userId == 0) {
        debugPrint("❌ Invalid userId");
        return;
      }

      final url = Uri.parse(
        "https://nextup-backend-zlou.onrender.com/api/provider/${widget.serviceId}",
      );

      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final List waitingList = data["waitingList"] ?? [];
        final current = data["currentlyServing"];

        // ✅ Check if user is currently being served
        if (current != null && current["userId"] == userId) {
          debugPrint("🔥 User is being served");
          setState(() {
            _status = "SERVING";
            _position = 0;
            _estimatedTime = 0;
          });
          return;
        }

        // ✅ Find user in waiting list
        final userQueue = waitingList.firstWhere(
              (q) => q["userId"] == userId,
          orElse: () => null,
        );

        // ✅ Not in queue and not serving = completed
        if (userQueue == null) {
          debugPrint("✅ User not in queue & not serving → completed");
          await prefs.remove('avgWaitTime');
          await _stopBackgroundTracking();

          if (!_isDialogShown && mounted) {
            _isDialogShown = true;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text("Done ✅"),
                content: const Text("Your request is completed. Thank you!"),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          }
          return;
        }

        int token = userQueue["tokenNumber"];
        String status = userQueue["status"];

        int position = waitingList.indexWhere(
              (q) => q["userId"] == userId,
        ) + 1;

        // ✅ FIX: fallback to current _estimatedTime if prefs is null
        // This preserves widget.estimatedTime set in initState on first poll
        int estimatedTime = prefs.getInt('avgWaitTime') ?? _estimatedTime;
        debugPrint("⏱ estimatedTime: $estimatedTime");

        if (_previousPosition != position) {
          if (position == 3) {
            await NotificationService.showNotification(
              "Almost Your Turn",
              "Only 2 people ahead",
            );
          } else if (position == 1) {
            await NotificationService.showNotification(
              "You Are Next!",
              "Proceed to counter",
            );
          }
          _previousPosition = position;
        }

        setState(() {
          _position = position;
          _estimatedTime = estimatedTime; // ✅ keeps correct value
          _status = status;
        });

      } else {
        debugPrint("❌ API error ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    _position = widget.position;
    _estimatedTime = widget.estimatedTime;
    _status = widget.status;
    notifiedFor3 = false;
    notifiedFor1 = false;

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _blinkAnimation =
        Tween<double>(begin: 0.4, end: 1.0).animate(_blinkController);

    _loadQueueStatus();

    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
          (timer) {
        if (mounted) _loadQueueStatus();
      },
    );

    _startBackgroundTracking(); // ✅ Start background tracking when screen opens
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _pollingTimer?.cancel();
    // ✅ Do NOT stop background service here — let it run after screen closes
    super.dispose();
  }

  // ── Status colors ────────────────────────────────────────────────────────
  Color get _accentColor {
    if (isProcessing) return const Color(0xFF16A34A);
    if (isNext) return const Color(0xFF4F46E5);
    return const Color(0xFF6366F1);
  }

  Color get _accentBg {
    if (isProcessing) return const Color(0xFFDCFCE7);
    if (isNext) return const Color(0xFFEEF2FF);
    return const Color(0xFFF1F5F9);
  }

  String get _statusLabel {
    if (isProcessing) return "Being Served";
    if (isNext) return "You're Next";
    return "Waiting";
  }

  String get _statusMessage {
    if (isProcessing) return "Please proceed to the service counter.";
    if (isNext) return "Get ready — you're next in line!";
    return "We'll notify you when it's your turn.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isProcessing
                    ? [const Color(0xFF15803D), const Color(0xFF16A34A)]
                    : [const Color(0xFF3730A3), const Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back + title row
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.serviceName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FadeTransition(
                                opacity: _blinkAnimation,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: isProcessing
                                        ? const Color(0xFF4ADE80)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _statusLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 44),
                      child: Text(
                        "Live Queue Status",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                children: [
                  // ── Token card ───────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Color top bar
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isProcessing
                                  ? [
                                const Color(0xFF16A34A),
                                const Color(0xFF4ADE80)
                              ]
                                  : isNext
                                  ? [
                                const Color(0xFF4F46E5),
                                const Color(0xFF818CF8)
                              ]
                                  : [
                                const Color(0xFF6366F1),
                                const Color(0xFFA5B4FC)
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                          child: Column(
                            children: [
                              Text(
                                "YOUR TOKEN",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade400,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Token number
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accentBg,
                                  border: Border.all(
                                    color: _accentColor.withOpacity(0.2),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "${widget.tokenNumber}",
                                    style: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w800,
                                      color: _accentColor,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Status message
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _accentBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isProcessing
                                          ? Icons.check_circle_outline_rounded
                                          : isNext
                                          ? Icons.notifications_active_outlined
                                          : Icons.hourglass_top_rounded,
                                      size: 16,
                                      color: _accentColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _statusMessage,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Typing dots when serving
                              if (isProcessing) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _typingDot(delay: 0),
                                    const SizedBox(width: 6),
                                    _typingDot(delay: 200),
                                    const SizedBox(width: 6),
                                    _typingDot(delay: 400),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Info cards row ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          icon: Icons.format_list_numbered_rounded,
                          label: "Position",
                          value: isProcessing ? "Serving" : "$_position",
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _infoCard(
                          icon: Icons.schedule_rounded,
                          label: "Est. Wait",
                          value: isProcessing ? "--" : "$_estimatedTime min",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Footer note ──────────────────────────────────────
                  Text(
                    isProcessing
                        ? "Please proceed to the service counter."
                        : "You will receive a notification when it's your turn.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                      height: 1.5,
                    ),
                  ),

                  // ── Cancel button ────────────────────────────────────
                  if (widget.status == "WAITING") ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text(
                          "Cancel Token",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        onPressed: () async {
                          final confirm = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text(
                                "Cancel Token?",
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              content: const Text(
                                "Are you sure you want to cancel this token?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    "No",
                                    style:
                                    TextStyle(color: Color(0xFF6B7280)),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDC2626),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text("Yes, Cancel"),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) cancelToken();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          foregroundColor: const Color(0xFFDC2626),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: Color(0xFFFECACA),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Info card ────────────────────────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ── Typing dot ───────────────────────────────────────────────────────────
  Widget _typingDot({required int delay}) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value as double,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// ── Premium Info Card (kept for compatibility) ────────────────────────────────
class _PremiumInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _PremiumInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF4F46E5), size: 26),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}