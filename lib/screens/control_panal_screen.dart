import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lab_to_lab_admin/screens/control_notifications_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_to_lab.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:lab_to_lab_admin/screens/patients_screen.dart';
import 'package:lab_to_lab_admin/screens/support_numbers_screen.dart';
import 'package:lab_to_lab_admin/screens/user_stats_screen.dart';
import 'package:lab_to_lab_admin/screens/claim_labs_picker_screen.dart';
import 'package:lab_to_lab_admin/screens/users_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ControlPanalScreen extends StatefulWidget {
  const ControlPanalScreen({super.key});

  @override
  State<ControlPanalScreen> createState() => _ControlPanalScreenState();
}

class _ControlPanalScreenState extends State<ControlPanalScreen> {
  int? _lastSeenPatientsMs;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadLastSeenPatients();
    _loadUserName();
  }

  Future<void> _loadLastSeenPatients() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeenPatientsMs = prefs.getInt('control_last_seen_patients');
    });
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('userName');
    // Fallback: try to read from Firestore using stored control_user_id
    if (name == null || name.isEmpty) {
      final controlUserId = prefs.getString('control_user_id');
      if (controlUserId != null) {
        try {
          final snap = await FirebaseFirestore.instance.collection('controlUsers').doc(controlUserId).get();
          if (snap.exists) {
            name = snap.data()?['userName']?.toString();
            if (name != null && name.isNotEmpty) {
              await prefs.setString('userName', name);
            }
          }
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _userName = name;
    });
  }
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

  Widget _buildPatientsCardWithBadge() {
    final BorderRadius cardRadius = BorderRadius.circular(12);
    final Color primary = const Color.fromARGB(255, 90, 138, 201);
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final int thresholdMs = _lastSeenPatientsMs ?? startOfToday.millisecondsSinceEpoch;
    final Timestamp thresholdTs = Timestamp.fromMillisecondsSinceEpoch(thresholdMs);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .where('createdAt', isGreaterThanOrEqualTo: thresholdTs)
          .snapshots(),
      builder: (context, snap) {
        final int count = snap.hasData ? snap.data!.docs.length : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: cardRadius),
              child: InkWell(
                borderRadius: cardRadius,
                onTap: () async {
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  setState(() {
                    _lastSeenPatientsMs = nowMs; // hide badge instantly
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('control_last_seen_patients', nowMs);
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientsScreen()),
                  );
                },
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FontAwesomeIcons.user, color: primary, size: 25),
                      const SizedBox(height: 8),
                      const Text(
                        'المرضى',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if ((_userName ?? '').isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(children: [
                    Icon(Icons.person,color: Color.fromARGB(255, 90, 138, 201),),
                   Text(
                    ' ${_userName!}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),])
                ),
              ),
            ],
            Expanded(
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
               Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SupportNumbersScreen()),
                );
              },
            ),
                  _buildControlCard(
              icon: Icons.notifications,
              title: 'الاشعارات',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ControlNotificationsScreen()));
              },
            ),
                  _buildControlCard(
              icon: Icons.query_stats,
              title: 'احصائيات ',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserStatsScreen()),
                );
              },
            ),
                  _buildControlCard(
              icon: Icons.people_alt,
              title: 'المستخدمين',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UsersScreen()),
                );
              },
            ),
                  _buildControlCard(
              icon: Icons.receipt_long,
              title: 'المطالبة',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ClaimLabsPickerScreen()),
                );
              },
            ),
                  _buildPatientsCardWithBadge(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}