import 'package:flutter/material.dart';
import 'package:nextup/screens/dashboard/dashboard_screen.dart';
import 'package:nextup/screens/service_provider_homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {


    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString('token');
      final String? role = prefs.getString('role');
      final int? userId = prefs.getInt('userId');
      final String name = prefs.getString('userName') ?? '';

      print("TOKEN: $token");
      print("ROLE: $role");
      print("USER ID: $userId");

      if (token != null && role != null && userId != null) {
        // ✅ Token exists → Skip login
        if (role == 'SERVICE_PROVIDER') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceProviderHomePage(providerId: userId),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => UserDashboard(userId: userId, userName: name),
            ),
          );
        }
      } else {
        // ❌ No token → Go to Welcome
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const WelcomeScreen(),
          ),
        );
      }
    } catch (e) {
      print("SPLASH ERROR: $e");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/nextup_logo.png',
          width: 160,
          height: 160,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
