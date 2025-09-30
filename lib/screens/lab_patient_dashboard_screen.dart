import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lab_to_lab_admin/screens/containers_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_patient_info_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_patient_result_detail_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_select_tests_screen.dart';

class LabPatientDashboardScreen extends StatelessWidget {
  final String labId;
  final String labName;
  final String patientDocId;
  
  const LabPatientDashboardScreen({
    super.key,
    required this.labId,
    required this.labName,
    required this.patientDocId,
  });
  
  Widget _buildCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color.fromARGB(255, 90, 138, 201),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة المريض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildCard(
                icon: Icons.add_circle,
                title: 'إضافة فحص',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LabSelectTestsScreen(
                        labId: labId,
                        labName: labName,
                        patientId: patientDocId,
                      ),
                    ),
                  );
                },
              ),
              _buildCard(
                icon: Icons.person,
                title: 'معلومات المريض',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LabPatientInfoScreen(
                        labId: labId,
                        labName: labName,
                        patientDocId: patientDocId,
                      ),
                    ),
                  );
                },
              ),
              _buildCard(
                icon: Icons.analytics,
                title: 'النتيجة',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LabPatientResultDetailScreen(
                        labId: labId,
                        labName: labName,
                        patientDocId: patientDocId,
                      ),
                    ),
                  );
                },
              ),
              _buildCard(
                icon: FontAwesomeIcons.vial,
                title: "أنابيب",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContainersScreen(
                        labId: labId,
                        labName: labName,
                        patientDocId: patientDocId,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
