import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_to_lab.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlPanalScreen extends StatefulWidget {
  const ControlPanalScreen({super.key});

  @override
  State<ControlPanalScreen> createState() => _ControlPanalScreenState();
}

class _ControlPanalScreenState extends State<ControlPanalScreen> {
  Widget _buildControlCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final BorderRadius cardRadius = BorderRadius.circular(12);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
      child: InkWell(
        borderRadius: cardRadius,
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color ?? const Color.fromARGB(255, 90, 138, 201), size: 25),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: Text("لوحة تحكم الكنترول",style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 90, 138, 201),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', false);
              await prefs.remove('userType');
              await prefs.remove('lab_id');
              await prefs.remove('labName');
              await prefs.remove('fromControlPanel');
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildControlCard(
              icon: Icons.biotech,
              title: 'المعامل',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LabToLab()),
                );
              },
            ),
            _buildControlCard(
              icon: Icons.support_agent,
              title: 'الدعم الفني',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فتح شاشة الدعم الفني')),
                );
              },
            ),
            _buildControlCard(
              icon: Icons.notifications,
              title: 'الاشعارات',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فتح شاشة الاشعارات')),
                );
              },
            ),
            _buildControlCard(
              icon: Icons.query_stats,
              title: 'احصائيات المستخدمين',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فتح شاشة احصائيات المستخدمين')),
                );
              },
            ),
            _buildControlCard(
              icon: Icons.people_alt,
              title: 'موظفين المعامل',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('فتح شاشة موظفين المعامل')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}