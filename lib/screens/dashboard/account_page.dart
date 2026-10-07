import 'package:nextup/screens/payments_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nextup/screens/login_screen.dart';

class AccountPage extends StatefulWidget {
  final String firstName;
  final String email;
  final String mobile;

  const AccountPage({
    super.key,
    required this.firstName,
    required this.email,
    required this.mobile,
  });

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController mobileController;

  bool editName = false;
  bool editMobile = false;
  bool _isSaving = false;

  late String originalName;
  late String originalEmail;
  late String originalMobile;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.firstName);
    emailController = TextEditingController(text: widget.email);
    mobileController = TextEditingController(text: widget.mobile);
    originalName = widget.firstName;
    originalEmail = widget.email;
    originalMobile = widget.mobile;
    _loadUserProfile();
  }

  bool get _hasChanges =>
      nameController.text.trim() != originalName ||
          mobileController.text.trim() != originalMobile;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  // ================= LOAD PROFILE =================
  Future<void> _loadUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse("http://192.168.1.34:8080/api/profile"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          nameController.text = data['name'] ?? nameController.text;
          emailController.text = data['email'] ?? emailController.text;
          mobileController.text = data['mobile'] ?? mobileController.text;
          originalName = nameController.text;
          originalEmail = emailController.text;
          originalMobile = mobileController.text;
        });
      }
    } catch (_) {}
  }

  // ================= SAVE CHANGES =================
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showError("Session expired. Please login again.");
        return;
      }

      final Map<String, dynamic> body = {};
      if (editName) body['name'] = nameController.text.trim();
      if (editMobile) body['mobile'] = mobileController.text.trim();

      final response = await http.put(
        Uri.parse("http://192.168.1.34:8080/api/profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          originalName = nameController.text.trim();
          originalMobile = mobileController.text.trim();
          editName = false;
          editMobile = false;
        });
        _showSuccess("Profile updated successfully");
      } else {
        _showError("Update failed");
      }
    } catch (_) {
      _showError("Server not reachable");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final initials = nameController.text.trim().isNotEmpty
        ? nameController.text.trim().split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join()
        : "?";

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      // Title row
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "My Profile",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name
                      Text(
                        nameController.text.isNotEmpty
                            ? nameController.text
                            : "Your Name",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Email
                      Text(
                        emailController.text.isNotEmpty
                            ? emailController.text
                            : "",
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
          ),

          // ── Body ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Info section
                  _sectionLabel("PERSONAL INFO"),
                  const SizedBox(height: 12),

                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _fieldTile(
                          label: "Full Name",
                          icon: Icons.person_outline_rounded,
                          controller: nameController,
                          enabled: editName,
                          showEdit: true,
                          onEdit: () => setState(() => editName = true),
                        ),
                        _divider(),
                        _fieldTile(
                          label: "Email Address",
                          icon: Icons.mail_outline_rounded,
                          controller: emailController,
                          enabled: false,
                          locked: true,
                        ),
                        _divider(),
                        _fieldTile(
                          label: "Mobile Number",
                          icon: Icons.phone_outlined,
                          controller: mobileController,
                          enabled: editMobile,
                          showEdit: true,
                          onEdit: () => setState(() => editMobile = true),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),

                  // Save button
                  if (_hasChanges) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          "Save Changes",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // More section
                  _sectionLabel("MORE"),
                  const SizedBox(height: 12),

                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        _actionTile(
                          icon: Icons.receipt_long_outlined,
                          label: "Payments",
                          iconColor: const Color(0xFF059669),
                          iconBg: const Color(0xFFECFDF5),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PaymentsPage()),
                          ),
                        ),
                        _divider(),
                        _actionTile(
                          icon: Icons.feedback_outlined,
                          label: "Send Feedback",
                          iconColor: const Color(0xFF4F46E5),
                          iconBg: const Color(0xFFEEF2FF),
                          onTap: _sendFeedback,
                        ),
                        _divider(),
                        _actionTile(
                          icon: Icons.logout_rounded,
                          label: "Log Out",
                          iconColor: const Color(0xFFDC2626),
                          iconBg: const Color(0xFFFEF2F2),
                          labelColor: const Color(0xFFDC2626),
                          onTap: _showLogoutConfirmation,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Center(
                    child: Text(
                      "NextUp v1.0.0",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9CA3AF),
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _fieldTile({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
    bool showEdit = false,
    bool locked = false,
    VoidCallback? onEdit,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: locked
                  ? const Color(0xFFF3F4F6)
                  : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 17,
              color: locked
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: keyboardType,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: locked
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF111827),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "Locked",
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else if (showEdit && !enabled)
            GestureDetector(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: Color(0xFF4F46E5),
                ),
              ),
            )
          else if (enabled)
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: Color(0xFF16A34A),
                ),
              ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
    Color? labelColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: labelColor ?? const Color(0xFF111827),
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.only(left: 66),
    child: Divider(height: 1, color: Colors.grey.shade100),
  );

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF16A34A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Log out?",
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Log out"),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  Future<void> _sendFeedback() async {
    final String email = "sunil.cs24024@mmcc.edu.in";
    final String subject = "NextUp App Feedback";
    final String body =
        "Hello Team,%0D%0A%0D%0AName: ${nameController.text}%0D%0AEmail: ${emailController.text}%0D%0A";
    final Uri mailUri =
    Uri.parse("mailto:$email?subject=$subject&body=$body");
    try {
      await launchUrl(mailUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _showError("Unable to open email.");
    }
  }
}
