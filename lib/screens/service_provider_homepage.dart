import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nextup/screens/scan_qr_screen.dart';
import 'package:nextup/screens/enter_code_screen.dart';
import 'package:nextup/screens/browse_services_screen.dart';
import 'package:nextup/screens/dashboard/help_page.dart';
import 'package:nextup/screens/dashboard/account_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'QueueScreen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_model.dart';
import '../services/service_api.dart';

class ServiceProviderHomePage extends StatefulWidget {
  final int providerId;

  const ServiceProviderHomePage({
    super.key,
    required this.providerId,
  });

  @override
  State<ServiceProviderHomePage> createState() =>
      _ServiceProviderHomePageState();
}

class _ServiceProviderHomePageState extends State<ServiceProviderHomePage>
    with TickerProviderStateMixin {
  // ── Palette ───────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFFEEF3FA);
  static const Color _surface  = Color(0xFFFFFFFF);
  static const Color _blue     = Color(0xFF2563EB);
  static const Color _blueSoft = Color(0xFFDBEAFE);
  static const Color _text1    = Color(0xFF0C1B2E);
  static const Color _text2    = Color(0xFF64748B);
  static const Color _text3    = Color(0xFFCBD5E1);
  static const Color _border   = Color(0xFFDDE6F0);
  static const Color _green    = Color(0xFF059669);
  static const Color _red      = Color(0xFFDC2626);

  // ── State ─────────────────────────────────────────────────────────────
  int  _currentIndex = 0;
  bool _isLoading    = true;
  bool _hasError     = false;
  List<ServiceModel> _services = [];

  // ── Delete edit-mode state ────────────────────────────────────────────
  bool _isEditMode       = false;
  int? _deletingServiceId;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  // ── API: fetch ────────────────────────────────────────────────────────
  Future<void> _fetchServices() async {

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {

      final prefs = await SharedPreferences.getInstance();

      String? token = prefs.getString("token");

      if (token == null) {
        throw Exception("Token not found");
      }

      final data = await ServiceApi.getServices(
        widget.providerId,
        token,
      );

      if (!mounted) return;

      setState(() {
        _services = data;
        _isLoading = false;
      });

    } catch (e) {

      print("❌ FETCH SERVICES ERROR: $e");

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // ── API: delete ───────────────────────────────────────────────────────
  Future<void> _confirmDelete(ServiceModel service) async {
    final confirm = await _showDeleteConfirmDialog(service.name);
    if (confirm != true) return;

    setState(() => _deletingServiceId = service.id);
    try {
      await ServiceApi.deleteService(service.id!);
      if (!mounted) return;
      setState(() {
        _services.removeWhere((s) => s.id == service.id);
        if (_services.isEmpty) _isEditMode = false;
      });
    } catch (e) {
      if (mounted) _showError("Failed to delete service.");
    } finally {
      if (mounted) setState(() => _deletingServiceId = null);
    }
  }

  // ── Back press ────────────────────────────────────────────────────────
  Future<bool> _onBackPressed() async {
    // Exit edit mode first instead of quitting the app
    if (_isEditMode) {
      setState(() => _isEditMode = false);
      return false;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _red.withOpacity(0.2)),
                ),
                child:
                const Icon(Icons.exit_to_app_rounded, color: _red, size: 24),
              ),
              const SizedBox(height: 18),
              const Text("Exit App?",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _text1)),
              const SizedBox(height: 8),
              const Text(
                "Are you sure you want to exit the application?",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _text2, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _text2,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _border),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Exit",
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    ) ??
        false;
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      _buildStatsTab(),
      _accountTab(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: WillPopScope(
        onWillPop: _onBackPressed,
        child: Scaffold(
          backgroundColor: _bg,
          extendBody: true,
          body: tabs[_currentIndex],

          // ── FAB ──────────────────────────────────────────────────────
          floatingActionButton: (_currentIndex == 0 && !_isEditMode)
              ? Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B7EFF), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _blue.withOpacity(0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _openAddServiceDialog();
                },
                child: const Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Add Service",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              : null,
          floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,

          // ── Bottom nav ────────────────────────────────────────────────
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      (Icons.grid_view_rounded,       Icons.grid_view_rounded,  "Services"),
      (Icons.bar_chart_rounded,       Icons.bar_chart_rounded,  "Stats"),
      (Icons.person_outline_rounded,  Icons.person_rounded,     "Account"),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final selected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    // Leaving home tab exits edit mode
                    if (_isEditMode) setState(() => _isEditMode = false);
                    setState(() => _currentIndex = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? _blue.withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? items[i].$2 : items[i].$1,
                          color: selected ? _blue : _text2,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? _blue : _text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // HOME TAB
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    return Column(
      children: [
        _buildHomeHeader(),
        Expanded(child: _buildServicesList()),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────
  Widget _buildHomeHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1441C4), Color(0xFF2563EB), Color(0xFF1B47C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x402563EB),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative orbs
          Positioned(
            top: -20, right: -16,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.07),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -10, left: 30,
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.only(
              top: topPad + 18,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Brand mark
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(11),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 🔹 Left Side (Title + Count)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "NextUp",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              Text(
                                "${_services.length} service${_services.length != 1 ? 's' : ''}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.55),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          // 🔹 Right Side (Help Button)
                          IconButton(
                            icon: const Icon(Icons.help_outline, color: Colors.white),
                            tooltip: "Help",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HelpPage()),
                              );
                            },
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
    );
  }

  // ── Services list body ────────────────────────────────────────────────
  Widget _buildServicesList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: _red, size: 28),
            ),
            const SizedBox(height: 16),
            const Text("Failed to load services",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _text1)),
            const SizedBox(height: 6),
            const Text("Check your connection and try again",
                style: TextStyle(fontSize: 13, color: _text2)),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: _fetchServices,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: const Text("Retry",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    }

    if (_services.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: _blueSoft, shape: BoxShape.circle),
              child: const Icon(Icons.storefront_outlined,
                  color: _blue, size: 32),
            ),
            const SizedBox(height: 18),
            const Text("No services yet",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _text1)),
            const SizedBox(height: 6),
            const Text("Tap 'Add Service' to get started",
                style: TextStyle(fontSize: 13, color: _text2)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchServices,
      color: _blue,
      backgroundColor: _surface,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
        children: [
          // ── "My Services" heading + edit-mode hint ──────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "My Services",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _text1,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 8),
              // Count pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_services.length}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _blue,
                  ),
                ),
              ),
              const Spacer(),
              // Edit mode hint (only in edit mode)
              if (_isEditMode)
                GestureDetector(
                  onTap: () =>
                      setState(() => _isEditMode = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                      Border.all(color: _red.withOpacity(0.25)),
                    ),
                    child: const Text(
                      "Done",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _red,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Edit mode banner
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _isEditMode
                ? Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                Border.all(color: _red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: _red.withOpacity(0.8), size: 15),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Tap the — icon on a service to delete it",
                      style: TextStyle(
                          fontSize: 12,
                          color: _red,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 14),

          // ── Service tiles ───────────────────────────────────────────
          ...List.generate(
            _services.length,
                (i) => _buildServiceTile(_services[i]),
          ),
        ],
      ),
    );
  }

  // ── Single service tile ───────────────────────────────────────────────
  Widget _buildServiceTile(ServiceModel service) {
    final isActive    = service.isActive ?? false;
    final isDeleting  = _deletingServiceId == service.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          if (_isEditMode) {
            // Tapping the card (not the delete badge) exits edit mode
            setState(() => _isEditMode = false);
            return;
          }
          if (service.id == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QueueScreen(
                serviceId:   service.id ?? 0,
                serviceName: service.name ?? "",
                isActive:    service.isActive ?? false,
                userId:      widget.providerId,
              ),
            ),
          ).then((refresh) {
            if (refresh == true) _fetchServices();
          });
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(() => _isEditMode = true);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Card body ─────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isEditMode
                      ? _red.withOpacity(0.25)
                      : _border,
                  width: _isEditMode ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Service icon
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                            color: _blue.withOpacity(0.12), width: 1),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: _blue, size: 22),
                    ),
                    const SizedBox(width: 14),

                    // Name + status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: _text1,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          // ── Active / Inactive badge ──────────────
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: isActive ? _green : _text3,
                                  shape: BoxShape.circle,
                                  boxShadow: isActive
                                      ? [
                                    BoxShadow(
                                        color:
                                        _green.withOpacity(0.55),
                                        blurRadius: 5)
                                  ]
                                      : [],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isActive ? "Tap to Manage Queue" : "Tap to Manage Queue",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? _green : _text2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Trailing slot ─────────────────────────────────
                    // Shows chevron normally; delete badge is in Stack
                    if (!_isEditMode)
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: _text2,
                          size: 18,
                        ),
                      )
                    else
                    // Spacer so layout doesn't shift when badge appears
                      const SizedBox(width: 34),
                  ],
                ),
              ),
            ),

            // ── Delete badge (edit mode only) ─────────────────────────
            if (_isEditMode)
              Positioned(
                top: -8, right: -8,
                child: GestureDetector(
                  onTap: () => _confirmDelete(service),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: _red,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _red.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isDeleting
                        ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white),
                    )
                        : const Icon(
                      Icons.remove_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ADD SERVICE DIALOG
  // ══════════════════════════════════════════════════════════════════════
  void _openAddServiceDialog() {
    final nameController        = TextEditingController();
    final descriptionController = TextEditingController();
    final capacityController    = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          Future<void> createService() async {
            final name        = nameController.text.trim();
            final description = descriptionController.text.trim();

            if (name.isEmpty || description.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Name and description required"),
                  backgroundColor: _red,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
              return;
            }

            int? maxCapacity;
            if (capacityController.text.trim().isNotEmpty) {
              maxCapacity = int.tryParse(capacityController.text);
              if (maxCapacity == null || maxCapacity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Enter valid capacity"),
                    backgroundColor: _red,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
                return;
              }
            }

            setStateDialog(() => isSaving = true);
            final prefs = await SharedPreferences.getInstance();

            String? token = prefs.getString("token");

            if (token == null) {
              throw Exception("Token not found");
            }

            try {
              final newService = await ServiceApi.createService({
                "providerId":  widget.providerId,
                "name":        name,
                "description": description,
                if (maxCapacity != null) "maxCapacity": maxCapacity,
              },
              token);
              if (!mounted) return;
              setState(() => _services.insert(0, newService));
              Navigator.pop(dialogContext);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: _red,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            } finally {
              if (mounted) setStateDialog(() => isSaving = false);
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 40),
            child: Container(
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dialog header
                      Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: _blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                                Icons.add_business_rounded,
                                color: _blue,
                                size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "New Service",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _text1,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  "Fill in the details below",
                                  style: TextStyle(
                                      fontSize: 12, color: _text2),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: isSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: _border),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: _text2, size: 16),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      Container(height: 1, color: _border),
                      const SizedBox(height: 22),

                      _premiumInputField(
                        label: "Service Name",
                        hint: "e.g. Haircut, Consultation",
                        controller: nameController,
                      ),
                      const SizedBox(height: 16),
                      _premiumInputField(
                        label: "Description",
                        hint: "Describe this service briefly",
                        controller: descriptionController,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _premiumInputField(
                        label: "Max Queue Capacity",
                        hint: "Leave empty for unlimited",
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        isOptional: true,
                      ),

                      const SizedBox(height: 26),

                      Row(children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: TextButton.styleFrom(
                              foregroundColor: _text2,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: _border),
                              ),
                            ),
                            child: const Text("Cancel",
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: isSaving ? null : createService,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: isSaving
                                    ? null
                                    : const LinearGradient(
                                  colors: [
                                    Color(0xFF3B7EFF),
                                    Color(0xFF1D4ED8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                color: isSaving ? _border : null,
                                borderRadius:
                                BorderRadius.circular(14),
                                boxShadow: isSaving
                                    ? []
                                    : [
                                  BoxShadow(
                                    color: _blue.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: isSaving
                                    ? const SizedBox(
                                  width: 18, height: 18,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  "Create Service",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // DELETE CONFIRM DIALOG
  // ══════════════════════════════════════════════════════════════════════
  Future<bool?> _showDeleteConfirmDialog(String serviceName) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: _red.withOpacity(0.2)),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _red, size: 26),
              ),
              const SizedBox(height: 18),
              const Text(
                "Delete Service?",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _text1),
              ),
              const SizedBox(height: 10),
              Text(
                "\"$serviceName\" will be permanently deleted. This cannot be undone.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _text2, height: 1.55),
              ),
              const SizedBox(height: 26),
              Row(children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: _text2,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: _border),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text("Cancel",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Delete",
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

  // ── QR Dialog ─────────────────────────────────────────────────────────
  void _showQrDialog(int serviceId, String serviceName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(serviceName,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _text1),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text("Scan to join this queue",
                  style: TextStyle(fontSize: 13, color: _text2)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withOpacity(0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: QrImageView(
                  data: serviceId.toString(),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done",
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error snackbar ────────────────────────────────────────────────────
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Input field ───────────────────────────────────────────────────────
  Widget _premiumInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines               = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isOptional            = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _text1)),
            if (isOptional) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border),
                ),
                child: const Text("Optional",
                    style: TextStyle(
                        fontSize: 10,
                        color: _text2,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: _text1),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            TextStyle(color: _text1.withOpacity(0.3), fontSize: 14),
            filled: true,
            fillColor: _bg,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // Kept for internal usage
  Widget _buildInputField(
      String label,
      TextEditingController controller, {
        int maxLines               = 1,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // OTHER TABS
  // ══════════════════════════════════════════════════════════════════════
  Widget _buildStatsTab() {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1441C4),
                Color(0xFF2563EB),
                Color(0xFF1B47C8)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                  color: Color(0x402563EB),
                  blurRadius: 28,
                  offset: Offset(0, 10)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
                top: topPad + 18, bottom: 24, left: 20, right: 20),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Statistics",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: const BoxDecoration(
                      color: _blueSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: _blue, size: 32),
                ),
                const SizedBox(height: 18),
                const Text("Coming Soon",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _text1)),
                const SizedBox(height: 6),
                const Text("Queue analytics will appear here",
                    style: TextStyle(fontSize: 13, color: _text2)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _accountTab() {
    return AccountPage(
      firstName: "",
      email: "",
      mobile: "",
    );
  }
}