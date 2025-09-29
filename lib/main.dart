import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:lab_to_lab_admin/screens/onboarding_landing.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_dashboard_screen.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final prefs = snap.data!;
        final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        final bool hasContract = prefs.getBool('hasContract') ?? false;
        final String? labId = prefs.getString('lab_id');
        final String? labName = prefs.getString('labName');

        Widget home;
        if (isLoggedIn && labId != null && labName != null) {
          home = LabDashboardScreen(labId: labId, labName: labName);
        } else if (hasContract) {
          home = const LoginScreen();
        } else {
          home = const OnboardingLandingScreen();
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: home,
        );
      },
    );
  }
}