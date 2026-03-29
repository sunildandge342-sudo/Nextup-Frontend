import 'package:flutter/material.dart';
import 'package:nextup/screens/dashboard/dashboard_screen.dart';
import 'package:nextup/services/background_service.dart';
import 'package:nextup/services/notification_service.dart';
import 'package:nextup/screens/service_provider_homepage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'screens/Welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize OneSignal
  await NotificationService.initOneSignal();

  // ✅ Keep existing local notification init
  await NotificationService.init(
    onTap: (payload) {
      debugPrint('User tapped notification with payload: $payload');
    },
  );

  await initBackgroundService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextUp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      ),
      home: const SplashScreen(),
    );
  }
}

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
    final prefsLoad = SharedPreferences.getInstance();

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final prefs = await prefsLoad;
      final String? token = prefs.getString('token');
      final String? role = prefs.getString('role');
      final int? userId = prefs.getInt('userId');
      final String name = prefs.getString('userName') ?? '';

      print("TOKEN: $token");
      print("ROLE: $role");
      print("USER ID: $userId");

      if (token != null && role != null && userId != null) {
        // ✅ Link OneSignal to logged-in user
        await NotificationService.setUserId(userId.toString());

        if (role == 'SERVICE_PROVIDER') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ServiceProviderHomePage(providerId: userId),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => UserDashboard(userId: userId, userName: name),
            ),
          );
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const WelcomeScreen(),
          ),
        );
      }
    } catch (e) {
      print("SPLASH ERROR: $e");
      Navigator.of(context).pushReplacement(
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/nextup_logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              "",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}