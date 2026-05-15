import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class QueueScreen extends StatefulWidget {
  final int userId;
  final int serviceId;
  final String serviceName;
  final bool isActive;

  const QueueScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.isActive,
    required this.userId,
  });

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> with TickerProviderStateMixin {
  // ── Theme ─────────────────────────────────────────────────────────────
  bool _isDark = false;

  // ── Dark Palette ──────────────────────────────────────────────────────
  static const Color _dBg         = Color(0xFF070E16);
  static const Color _dCard       = Color(0xFF0F1C28);
  static const Color _dCardHigh   = Color(0xFF132030);
  static const Color _dBlue       = Color(0xFF4A9EFF);
  static const Color _dGreen      = Color(0xFF2DD882);
  static const Color _dRed        = Color(0xFFFF5C6C);
  static const Color _dAmber      = Color(0xFFFFBB38);
  static const Color _dText1      = Color(0xFFE8F0FF);
  static const Color _dText2      = Color(0xFF6282A0);
  static const Color _dText3      = Color(0xFF243649);
  static const Color _dBorder     = Color(0xFF131F2E);
  static const Color _dBorderHigh = Color(0xFF1B2E42);

  // ── Light Palette ─────────────────────────────────────────────────────
  static const Color _lBg         = Color(0xFFEEF3FA);
  static const Color _lCard       = Color(0xFFFFFFFF);
  static const Color _lCardHigh   = Color(0xFFF3F8FF);
  static const Color _lBlue       = Color(0xFF2563EB);
  static const Color _lGreen      = Color(0xFF059669);
  static const Color _lRed        = Color(0xFFDC2626);
  static const Color _lAmber      = Color(0xFFB45309);
  static const Color _lText1      = Color(0xFF0C1B2E);
  static const Color _lText2      = Color(0xFF64748B);
  static const Color _lText3      = Color(0xFFCBD5E1);
  static const Color _lBorder     = Color(0xFFDDE6F0);
  static const Color _lBorderHigh = Color(0xFFBDD0E8);

  // ── Dynamic getters ───────────────────────────────────────────────────
  Color get _bg         => _isDark ? _dBg         : _lBg;
  Color get _card       => _isDark ? _dCard       : _lCard;
  Color get _cardHigh   => _isDark ? _dCardHigh   : _lCardHigh;
  Color get _blue       => _isDark ? _dBlue       : _lBlue;
  Color get _green      => _isDark ? _dGreen      : _lGreen;
  Color get _red        => _isDark ? _dRed        : _lRed;
  Color get _amber      => _isDark ? _dAmber      : _lAmber;
  Color get _t1         => _isDark ? _dText1      : _lText1;
  Color get _t2         => _isDark ? _dText2      : _lText2;
  Color get _t3         => _isDark ? _dText3      : _lText3;
  Color get _border     => _isDark ? _dBorder     : _lBorder;
  Color get _borderHigh => _isDark ? _dBorderHigh : _lBorderHigh;

  // ── Queue state ───────────────────────────────────────────────────────
  Map<String, dynamic>? currentServing;
  List<dynamic> waitingList = [];
  bool _isDisposed      = false;
  late bool _isActive;
  bool _isCallingNext   = false;
  bool _isMarkingServed = false;

  // ── Stale-response guard ──────────────────────────────────────────────
  int _serveGeneration = 0;

  // ── Timer state ───────────────────────────────────────────────────────
  Timer?    _uiTimer;
  int       _pollCounter      = 0;
  DateTime? _servingStartTime;
  int?      _trackedTokenNumber;

  final String baseUrl = "https://nextup-backend-zlou.onrender.com/api";

  // ── Timer display ─────────────────────────────────────────────────────
  String _getLiveTime() {
    if (_servingStartTime == null) return "00:00";
    final diff = DateTime.now().difference(_servingStartTime!);
    final m = diff.inMinutes.toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _syncTimer() {
    final serving = currentServing;
    if (serving == null || serving["status"] != "SERVING") {
      _servingStartTime   = null;
      _trackedTokenNumber = null;
      return;
    }
    final tokenNumber = serving["tokenNumber"] as int?;
    if (tokenNumber != null && tokenNumber == _trackedTokenNumber) return;
    _trackedTokenNumber = tokenNumber;
    final servedAtStr = serving["servedAt"] as String?;
    if (servedAtStr != null) {
      try { _servingStartTime = DateTime.parse(servedAtStr); return; } catch (_) {}
    }
    _servingStartTime = DateTime.now();
  }

  // ── API ───────────────────────────────────────────────────────────────
  Future<void> _loadQueue({int? callerGeneration}) async {
    if (_isDisposed) return;
    if (_isMarkingServed) return;

    final generationAtStart = callerGeneration ?? _serveGeneration;

    try {
      final response = await http
          .get(Uri.parse("$baseUrl/queue/${widget.serviceId}"))
          .timeout(const Duration(seconds: 8));

      if (_isDisposed || !mounted) return;
      if (_serveGeneration != generationAtStart) return;
      if (_isMarkingServed) return;

      if (response.statusCode != 200) {
        debugPrint("Queue API failed: ${response.statusCode}");
        return;
      }

      final raw          = jsonDecode(response.body);
      final serving      = raw["currentlyServing"] as Map<String, dynamic>?;
      final waiting      = raw["waitingList"] as List? ?? [];
      final activeStatus = raw["active"] as bool? ?? false;

      if (_isDisposed || !mounted) return;
      if (_serveGeneration != generationAtStart) return;
      if (_isMarkingServed) return;

      setState(() {
        currentServing = serving;
        waitingList    = waiting;
        _isActive      = activeStatus;
        _syncTimer();
      });
    } catch (e) {
      if (!_isDisposed && mounted) debugPrint("Queue load error: $e");
    }
  }

  Future<void> _toggleStatus(bool value) async {
    try {
      final response = await http.patch(
        Uri.parse("$baseUrl/provider/services/${widget.serviceId}/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"isActive": value}),
      );
      if (response.statusCode == 200) {
        setState(() => _isActive = value);
      } else {
        _showError("Failed to update service status.");
      }
    } catch (e) {
      _showError("Network error.");
    }
  }

  Future<void> _callNext() async {
    if (_isCallingNext) return;
    setState(() {
      _isCallingNext      = true;
      _servingStartTime   = null;
      _trackedTokenNumber = null;
    });
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/provider/${widget.serviceId}/call-next"),
      );
      if (response.statusCode == 200) {
        await _loadQueue(callerGeneration: _serveGeneration);
      } else {
        debugPrint("Call next failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Call next error: $e");
    } finally {
      if (mounted) setState(() => _isCallingNext = false);
    }
  }

  Future<void> _serveCurrent() async {
    if (currentServing == null || _isMarkingServed) return;

    _serveGeneration++;
    final myGeneration = _serveGeneration;
    _isMarkingServed = true;

    setState(() {
      currentServing      = null;
      waitingList         = List.from(waitingList);
      _servingStartTime   = null;
      _trackedTokenNumber = null;
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/provider/${widget.serviceId}/complete-current"),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await _loadQueue(callerGeneration: myGeneration);
      } else {
        debugPrint("Complete current failed: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) debugPrint("Serve error: $e");
    } finally {
      if (mounted) {
        setState(() => _isMarkingServed = false);
      }
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _isActive = widget.isActive;
    _loadQueue(callerGeneration: 0);

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _pollCounter++;
      if (_pollCounter % 5 == 0) {
        _loadQueue(callerGeneration: _serveGeneration);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _uiTimer?.cancel();
    super.dispose();
  }

  // ── Dialogs ───────────────────────────────────────────────────────────
  Future<bool?> _showDeactivateDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _red.withOpacity(0.25), width: 1.5),
                ),
                child: Icon(Icons.power_settings_new_rounded, color: _red, size: 26),
              ),
              const SizedBox(height: 20),
              Text("Deactivate Service?",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _t1)),
              const SizedBox(height: 10),
              Text(
                "Users won't be able to join the queue while the service is inactive.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _t2, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _t2,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: _border),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Deactivate",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.serviceName,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _t1),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text("Scan to join this queue",
                  style: TextStyle(fontSize: 13, color: _t2)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: _blue.withOpacity(0.2),
                        blurRadius: 30, offset: const Offset(0, 8)),
                  ],
                ),
                child: QrImageView(
                  data: widget.serviceId.toString(),
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Done", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final bool isServing    = currentServing != null && currentServing?["status"] == "SERVING";
    final bool timerRunning = _servingStartTime != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
        color: _bg,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              _buildHeroHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildServingCard(isServing, timerRunning),
                        const SizedBox(height: 28),
                        _buildWaitingSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // HERO HEADER — immersive top zone with stats + controls
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildHeroHeader() {
    final topPad = MediaQuery.of(context).padding.top;

    // Header gradient colors
    final List<Color> gradColors = _isDark
        ? const [Color(0xFF091828), Color(0xFF0B2035), Color(0xFF091828)]
        : const [Color(0xFF1441C4), Color(0xFF2563EB), Color(0xFF1B47C8)];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: (_isDark ? _dBlue : _lBlue).withOpacity(0.28),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Background glow orbs ──────────────────────────────────────
          Positioned(
            top: -24, right: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.06), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 40,
            child: Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              top: topPad + 16,
              bottom: 26,
              left: 20,
              right: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Nav row ────────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back
                    _navIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 14),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Live Queue Management",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // QR (if active)
                    if (_isActive) ...[
                      _navIconBtn(
                        icon: Icons.qr_code_rounded,
                        onTap: _showQrDialog,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // ── Theme toggle ──────────────────────────────────
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isDark = !_isDark);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.18)),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: Icon(
                            _isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                            key: ValueKey(_isDark),
                            color: Colors.white,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                // ── Stats row ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Waiting count
                    _buildHeroStat(
                      value: "${waitingList.length}",
                      label: "Waiting",
                      accentColor: const Color(0xFFFFBB38),
                      icon: Icons.people_alt_rounded,
                    ),

                    // Separator
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        width: 1, height: 38,
                        color: Colors.white.withOpacity(0.14),
                      ),
                    ),

                    // Token serving
                    _buildHeroStat(
                      value: currentServing != null
                          ? "#${currentServing!["tokenNumber"] ?? "—"}"
                          : "—",
                      label: "Now Serving",
                      accentColor: const Color(0xFF2DD882),
                      icon: Icons.confirmation_number_outlined,
                    ),

                    const Spacer(),

                    // Status toggle (tappable pill, replaces old switch+badge combo)
                    _buildStatusPill(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Small icon button used in the nav bar
  Widget _navIconBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildHeroStat({
    required String value,
    required String label,
    required Color accentColor,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.5),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -1.5,
            shadows: [Shadow(color: accentColor.withOpacity(0.5), blurRadius: 16)],
          ),
        ),
      ],
    );
  }

  // Tappable active/inactive pill — replaces the old Switch + badge combo
  Widget _buildStatusPill() {
    final color = _isActive ? const Color(0xFF2DD882) : const Color(0xFFFF5C6C);
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (_isActive) {
          final confirm = await _showDeactivateDialog();
          if (confirm == true) _toggleStatus(false);
        } else {
          _toggleStatus(true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.45), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isActive ? "Active" : "Inactive",
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: color, letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              "tap to toggle",
              style: TextStyle(
                fontSize: 9, color: color.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // SERVING CARD
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildServingCard(bool isServing, bool timerRunning) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isServing ? _blue.withOpacity(0.45) : _border,
          width: isServing ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isServing)
            BoxShadow(
              color: _blue.withOpacity(_isDark ? 0.22 : 0.14),
              blurRadius: 36,
              offset: const Offset(0, 12),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(_isDark ? 0.22 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
        ],
      ),
      child: Column(
        children: [
          // ── Card header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_pin_rounded, color: _blue, size: 15),
                ),
                const SizedBox(width: 10),
                Text(
                  "Currently Serving",
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _t2, letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                // Live timer chip
                AnimatedOpacity(
                  opacity: timerRunning ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined, color: _amber, size: 12),
                        const SizedBox(width: 5),
                        Text(
                          _getLiveTime(),
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _amber,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Customer row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: currentServing != null
                ? _buildCustomerRow(isServing)
                : _buildEmptyServingRow(),
          ),

          const SizedBox(height: 18),

          // ── Divider ───────────────────────────────────────────────────
          Container(height: 1, color: _border),

          // ── Action buttons ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildMarkServedBtn(isServing)),
                const SizedBox(width: 10),
                Expanded(child: _buildCallNextBtn()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(bool isServing) {
    final name    = (currentServing?["userName"] ?? "?").toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Row(
      children: [
        // Gradient avatar
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_blue.withOpacity(0.7), _blue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: _blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Name + token
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700,
                  color: _t1, letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 11, color: _t2),
                  const SizedBox(width: 4),
                  Text(
                    "Token ${currentServing?["tokenNumber"] ?? "—"}",
                    style: TextStyle(fontSize: 12, color: _t2),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Status badge
        if (isServing)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _green.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(
                    color: _green, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _green.withOpacity(0.7), blurRadius: 5)],
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "SERVING",
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: _green, letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyServingRow() {
    return Row(
      children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(color: _border, shape: BoxShape.circle),
          child: Icon(Icons.person_off_outlined, color: _t3, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          _isMarkingServed ? "Completing..." : "No one being served",
          style: TextStyle(fontSize: 15, color: _t2, fontWeight: FontWeight.w500),
        ),
        if (_isMarkingServed) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
          ),
        ],
      ],
    );
  }

  // ── Mark Served button ────────────────────────────────────────────────
  Widget _buildMarkServedBtn(bool isServing) {
    final active = isServing && !_isMarkingServed;
    return GestureDetector(
      onTap: active ? _serveCurrent : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 48,
        decoration: BoxDecoration(
          color: active ? _green : _border,
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))]
              : [],
        ),
        child: Center(
          child: _isMarkingServed
              ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_rounded, size: 16,
                  color: active ? Colors.white : _t2),
              const SizedBox(width: 6),
              Text(
                "Mark Served",
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _t2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Call Next button ──────────────────────────────────────────────────
  Widget _buildCallNextBtn() {
    final enabled = !_isCallingNext && !_isMarkingServed;
    return GestureDetector(
      onTap: enabled ? _callNext : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
            colors: [_blue, Color.lerp(_blue, Colors.blue.shade300, 0.25)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: enabled ? null : _border,
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [BoxShadow(color: _blue.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))]
              : [],
        ),
        child: Center(
          child: _isCallingNext
              ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.skip_next_rounded, size: 18,
                  color: enabled ? Colors.white : _t2),
              const SizedBox(width: 5),
              Text(
                "Call Next",
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : _t2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // WAITING SECTION
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildWaitingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label + count pill
        Row(
          children: [
            Text(
              "Waiting in Queue",
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700,
                color: _t1, letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 8),
            if (waitingList.isNotEmpty)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${waitingList.length}",
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: _blue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // Empty state
        if (waitingList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 42),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: _border, shape: BoxShape.circle),
                  child: Icon(Icons.inbox_outlined, color: _t2, size: 26),
                ),
                const SizedBox(height: 14),
                Text("Queue is empty",
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _t2,
                    )),
                const SizedBox(height: 4),
                Text("No customers waiting right now",
                    style: TextStyle(fontSize: 12, color: _t3)),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: waitingList.length,
            itemBuilder: (_, i) => _buildWaitingTile(i),
          ),
      ],
    );
  }

  Widget _buildWaitingTile(int index) {
    final user    = waitingList[index];
    final isFirst = index == 0;
    final name    = (user["userName"] ?? "User").toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isFirst ? _cardHigh : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFirst ? _borderHigh : _border,
            width: isFirst ? 1.5 : 1.0,
          ),
          boxShadow: isFirst
              ? [BoxShadow(
            color: _blue.withOpacity(_isDark ? 0.08 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          )]
              : [],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Position circle
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: isFirst ? _blue.withOpacity(0.14) : _border,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: isFirst ? _blue : _t2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),

              // Name + token
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: isFirst ? _t1 : _t2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Token #${user["tokenNumber"] ?? "—"}",
                      style: TextStyle(fontSize: 11, color: _t2),
                    ),
                  ],
                ),
              ),

              // NEXT badge or chevron
              if (isFirst)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withOpacity(0.35)),
                  ),
                  child: Text(
                    "NEXT",
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: _amber, letterSpacing: 0.6,
                    ),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: _t3, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}