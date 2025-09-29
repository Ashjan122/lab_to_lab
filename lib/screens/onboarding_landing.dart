import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:lab_to_lab_admin/screens/register_lab_screen.dart';

class OnboardingLandingScreen extends StatelessWidget {
  const OnboardingLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey.shade200,
                const Color.fromARGB(255, 90, 138, 201).withOpacity(0.2),
                const Color.fromARGB(255, 90, 138, 201).withOpacity(0.35),
              ],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: 96,
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'إدارة المعامل الطبية',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'اختر ما تريد القيام به للبدء',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterLabScreen())),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 90, 138, 201),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('إنشاء تعاقد جديد'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


