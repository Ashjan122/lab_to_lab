import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lab_to_lab_admin/screens/containers_screen.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('labToLap')
                    .doc('global')
                    .collection('patients')
                    .doc(patientDocId)
                    .get(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }
                  final data = snap.data?.data() ?? {};
                  final name = data['name']?.toString() ?? '';
                  final phone = data['phone']?.toString() ?? '';
                  final idDyn = data['id'];
                  final idStr = (idDyn is int) ? idDyn.toString() : (idDyn?.toString() ?? patientDocId);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المريض: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('كود المريض : $idStr'),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(' رقم الهاتف: $phone'),
                      ],
                      const Divider(height: 24),
                    ],
                  );
                },
              ),
              Expanded(
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
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('labToLap')
                  .doc('global')
                  .collection('patients')
                  .doc(patientDocId)
                  .snapshots(),
              builder: (context, snap) {
                final received = (snap.data?.data()?['order_receieved'] == true);
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: received
                        ? null
                        : () async {
                            // 1) Mark order as received
                            await FirebaseFirestore.instance
                                .collection('labToLap')
                                .doc('global')
                                .collection('patients')
                                .doc(patientDocId)
                                .set({'order_receieved': true}, SetOptions(merge: true));

                            // 2) Load patient to get name & phone
                            final pSnap = await FirebaseFirestore.instance
                                .collection('labToLap')
                                .doc('global')
                                .collection('patients')
                                .doc(patientDocId)
                                .get();
                            final pData = pSnap.data() ?? {};
                            final patientName = pData['name']?.toString() ?? 'غير معروف';
                            final patientPhone = pData['phone']?.toString() ?? '';

                            // 3) Send push request to lab-specific topic
                            final topic = 'lab_order_received_' + labId;
                            const title = 'تم استلام طلبك';
                            final body = patientPhone.isNotEmpty
                                ? 'اسم المريض: ' + patientName + '\nرقم الهاتف: ' + patientPhone
                                : 'اسم المريض: ' + patientName;

                            await FirebaseFirestore.instance.collection('push_requests').add({
                              'topic': topic,
                              'title': title,
                              'body': body,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 90, 138, 201),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(received ? 'تم الاستلام' : 'استلام الطلب'),
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
