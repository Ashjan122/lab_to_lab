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
import 'package:lab_to_lab_admin/screens/update_checker.dart';
import 'package:lottie/lottie.dart';

// import 'package:lab_to_lab_admin/screens/lab_order_received_notifications_screen.dart';

class LabDashboardScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const LabDashboardScreen({
    super.key,
    required this.labId,
    required this.labName,
  });

  @override
  State<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends State<LabDashboardScreen> {
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // فحص التحديثات مرة واحدة فقط
    if (!_hasCheckedUpdate) {
      _hasCheckedUpdate = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          UpdateChecker.checkForUpdate(context);
        }
      });
    }
  }

  Widget _buildCard({
    required Widget iconWidget,
    required String title,
    required VoidCallback onTap,
    bool enabled = true,
    Color color = const Color.fromARGB(255, 90, 138, 201),
  }) {
    final BorderRadius cardRadius = BorderRadius.circular(12);
    final Color resolvedColor = enabled ? color : Colors.grey.shade400;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final iconSize = (width * 0.25).clamp(
          20.0,
          32.0,
        ); // أيقونة متناسبة مع العرض
        final fontSize = (width * 0.10).clamp(20.0, 24.0);

        return Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: cardRadius),
            child: InkWell(
              borderRadius: cardRadius,
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,

                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: enabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    iconWidget,
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
            title: Text(
              widget.labName.contains('معمل')
                  ? widget.labName
                  : 'معمل ${widget.labName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
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
            width: double.infinity,
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: StreamBuilder(
                stream:
                    FirebaseFirestore.instance
                        .collection('labToLap')
                        .doc(widget.labId)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Center(child: Text("لا توجد بيانات حالياً"));
                  }
                  final doc = snapshot.data!;
                  final docData = doc.data() ?? {};
                  final bool isApproved = docData['isApproved'] != false;
                  final bool isAvailable = docData['available'] != false;

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        GridView.count(
                          crossAxisCount: 1,
                          childAspectRatio: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildCard(
                              iconWidget: Lottie.asset(
                                'assets/lordicons/Medical Animation _ Syringe _ Injection.json',
                                width: 60,
                                height: 60,
                              ),
                              title: 'عينة جديدة',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => LabNewSampleScreen(
                                          labId: widget.labId,
                                          labName: widget.labName,
                                        ),
                                  ),
                                );
                              },
                              enabled: isApproved && isAvailable,
                            ),
                            _buildCard(
                              iconWidget: Lottie.asset(
                                'assets/lordicons/Search.json',
                                width: 60,
                                height: 60,
                              ),
                              title: 'المرضى',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => LabResultsPatientsScreen(
                                          labId: widget.labId,
                                          labName: widget.labName,
                                        ),
                                  ),
                                );
                              },
                            ),
                            _buildCard(
                              iconWidget: Lottie.asset(
                                'assets/lordicons/Printer.json',
                                width: 60,
                                height: 60,
                              ),
                              title: "المطالبة",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ClaimScreen(
                                          labId: widget.labId,
                                          labName: widget.labName,
                                        ),
                                  ),
                                );
                              },
                            ),
                            _buildCard(
                              iconWidget: Lottie.asset(
                                'assets/lordicons/Contact us (1).json',
                                width: 60,
                                height: 60,
                              ),
                              title: "الدعم الفني",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => LabSupportNumbersScreen(),
                                  ),
                                );
                              },
                            ),
                            _buildCard(
                              iconWidget: Lottie.asset(
                                'assets/lordicons/Gears Lottie Animation.json',
                                width: 60,
                                height: 60,
                              ),
                              title: "إعدادات",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => LabSettingsScreen(
                                          labId: widget.labId,
                                          labName: widget.labName,
                                        ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 30),
                        if (!isApproved) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'قائمة الاسعار ستضاف بعد اعتماد التعاقد من المعمل المركزي',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
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
      ),
    );
  }
}

Future<bool> _shouldShowBackToControl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('fromControlPanel') == true;
}
