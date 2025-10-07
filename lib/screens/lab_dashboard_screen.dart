import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lab_to_lab_admin/screens/claim_screen.dart';
// import 'package:lab_to_lab_admin/screens/lab_info_screen.dart';
// import 'package:lab_to_lab_admin/screens/lab_location_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_new_sample_screen.dart';
// import 'package:lab_to_lab_admin/screens/lab_price_list_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_results_patients_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_settings_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_support_numbers_screen.dart';
// import 'package:lab_to_lab_admin/screens/lab_users_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_to_lab.dart';
// import 'package:lab_to_lab_admin/screens/lab_order_received_notifications_screen.dart';


class LabDashboardScreen extends StatelessWidget {
  final String labId;
  final String labName;
  const LabDashboardScreen({super.key, required this.labId, required this.labName});

  
  Widget _buildCard({required IconData icon, required String title, required VoidCallback onTap, bool enabled = true, Color color = const Color.fromARGB(255, 90, 138, 201)}) {
    final Color resolvedColor = enabled ? color : Colors.grey;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: resolvedColor, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: resolvedColor.withOpacity(enabled ? 1 : 0.5)),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: enabled ? null : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBackToControl(BuildContext context) async {
    final shouldShow = await _shouldShowBackToControl();
    if (shouldShow) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LabToLab()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: WillPopScope(
        onWillPop: () async {
          _navigateBackToControl(context);
          return false; // Prevent default back behavior
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text('لوحة $labName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          leading: FutureBuilder<bool>(
            future: _shouldShowBackToControl(),
            builder: (context, snapshot) {
              final show = snapshot.data == true;
              if (!show) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'الرجوع للكنترول',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => _navigateBackToControl(context),
              );
            },
          ),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('lab_id');
                await prefs.remove('labName');
                // تسجيل خروج كامل حتى لو كان الدخول من الكنترول
                await prefs.setBool('isLoggedIn', false);
                // يبقى hasContract = true ليعود لشاشة تسجيل الدخول
                await prefs.remove('userType');
                await prefs.remove('centerId');
                await prefs.remove('centerName');
                await prefs.remove('fromControlPanel');
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('labToLap')
                .doc(labId)
               
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!snapshot.hasData || !snapshot.data!.exists) {
  return const Center(child: Text("لا توجد بيانات حالياً"));
}
final doc = snapshot.data!;
final docData = doc?.data() as Map<String, dynamic>? ?? {};
final bool isApproved = docData['isApproved'] != false;



              return SingleChildScrollView(
                child: Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 3,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildCard(
                          icon: FontAwesomeIcons.syringe,
                          title: 'عينة جديدة',
                          enabled: isApproved,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder:  (context) => LabNewSampleScreen(labId: labId, labName: labName)));
                          },
                        ),
                        _buildCard(
                          icon: Icons.print,
                          title: 'المرضى',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder:  (context) => LabResultsPatientsScreen(labId: labId, labName: labName)));
                          },
                        ),
                        _buildCard(icon: Icons.receipt_long, title: "المطالبة", onTap: (){
                           Navigator.push(context, MaterialPageRoute(builder:  (context) => ClaimScreen(labId: labId, labName: labName)));
                        }),
                        _buildCard(icon: Icons.support_agent, title: "الدعم الفني", onTap: (){
                           Navigator.push(context, MaterialPageRoute(builder:  (context) => LabSupportNumbersScreen()));
                        }),
                        _buildCard(icon: Icons.settings, title: "إعدادات", onTap: (){
                          Navigator.push(context, MaterialPageRoute(builder:  (context) => LabSettingsScreen(labId: labId, labName: labName)));
                        }),
                      ],
                    ),
                    SizedBox(height: 30,),
                    if (!isApproved) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'قائمة الاسعار ستضاف بعد اعتماد التعاقد من المعمل المركزي',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}

Future<bool> _shouldShowBackToControl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('fromControlPanel') == true;
}
  
