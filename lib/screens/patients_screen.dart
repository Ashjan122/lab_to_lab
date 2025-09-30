import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_patient_dashboard_screen.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  Future<String> _getLabName(String labId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('labToLap')
          .doc(labId)
          .get();
      return doc.data()?['name']?.toString() ?? 'غير محدد';
    } catch (e) {
      return 'غير محدد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المرضى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('labToLap')
              .doc('global')
              .collection('patients')
              .orderBy('id')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}'));
            }
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('لا يوجد مرضى'));
            }

            return ListView.separated(
              itemCount: docs.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final doc = docs[index];
                final data = doc.data();
                final patientId = data['id']?.toString() ?? '';
                final patientName = data['name']?.toString() ?? '';
                final labId = data['labId']?.toString() ?? '';
                final patientDocId = doc.id;

                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color.fromARGB(255, 90, 138, 201),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          patientId,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 90, 138, 201),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: FutureBuilder<String>(
                      future: _getLabName(labId),
                      builder: (context, labSnapshot) {
                        final labName = labSnapshot.data ?? 'جاري التحميل...';
                        return Text(
                          'المعمل: $labName',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Color.fromARGB(255, 90, 138, 201),
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LabPatientDashboardScreen(
                            labId: labId.isNotEmpty ? labId : 'global',
                            labName: 'المعمل', // Will be updated when lab name loads
                            patientDocId: patientDocId,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
