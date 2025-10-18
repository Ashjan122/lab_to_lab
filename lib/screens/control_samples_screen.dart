import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/order_request_screen.dart'; // تأكد من المسار الصحيح

class ControlSamplesScreen extends StatefulWidget {
  const ControlSamplesScreen({super.key});

  @override
  State<ControlSamplesScreen> createState() => _ControlSamplesScreenState();
}

class _ControlSamplesScreenState extends State<ControlSamplesScreen> {
  // جلب المرضى اليوميين وجمعهم حسب المعمل
  Future<Map<String, List<Map<String, dynamic>>>> _getLabsWithPatientsToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final snapshot = await FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    final allPatients = snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id; // إضافة docId
      return data;
    }).toList();

    // ✅ ترتيب المرضى حسب التاريخ من الأحدث إلى الأقدم
    allPatients.sort((a, b) {
      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    final Map<String, List<Map<String, dynamic>>> groupedByLab = {};
    for (var patient in allPatients) {
      final labId = patient['labId']?.toString() ?? 'unknown';
      if (!groupedByLab.containsKey(labId)) {
        groupedByLab[labId] = [];
      }
      groupedByLab[labId]!.add(patient);
    }

    return groupedByLab;
  }

  // جلب اسم المعمل حسب labId
  Future<String> _getLabName(String labId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('labToLap').doc(labId).get();
      return doc.data()?['name'] ?? 'غير معروف';
    } catch (_) {
      return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'عينات اليوم',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF673AB7),
        ),
        body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _getLabsWithPatientsToday(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            final labsMap = snapshot.data ?? {};

            if (labsMap.isEmpty) {
              return const Center(child: Text('لا توجد عينات مضافة اليوم.'));
            }

            final labIds = labsMap.keys.toList();

            return ListView.builder(
              itemCount: labIds.length,
              itemBuilder: (context, index) {
                final labId = labIds[index];
                final patientsList = labsMap[labId]!;
                final patientCount = patientsList.length;

                return FutureBuilder<String>(
                  future: _getLabName(labId),
                  builder: (context, labSnapshot) {
                    final labName = labSnapshot.data ?? 'جاري التحميل...';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Card(
                        color: const Color.fromARGB(255, 245, 243, 243),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          title: Text(
                            labName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          trailing: Text('$patientCount مريض', style: const TextStyle(color: Colors.grey)),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (context) => DraggableScrollableSheet(
                                expand: false,
                                initialChildSize: 0.6,
                                minChildSize: 0.4,
                                maxChildSize: 0.9,
                                builder: (context, scrollController) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'مرضى $labName',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: Directionality(
                                            textDirection: TextDirection.rtl,
                                            child: ListView.builder(
                                              controller: scrollController,
                                              itemCount: patientsList.length,
                                              itemBuilder: (_, i) {
                                                final p = patientsList[i];
                                                final patientName = p['name'] ?? 'بدون اسم';
                                                final patientId = p['id']?.toString() ?? 'غير متوفر';
                                                final patientDocId = p['docId']?.toString() ?? '';

                                                return Card(
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                                  child: InkWell(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => OrderRequestScreen(
                                                            labId: labId,
                                                            labName: labName,
                                                            patientDocId: patientDocId,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                      child: Row(
                                                        children: [
                                                          // ✅ مربع الكود
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            decoration: BoxDecoration(
                                                              color: Colors.white,
                                                              border: Border.all(
                                                                color: const Color(0xFF673AB7),
                                                                width: 2,
                                                              ),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              patientId,
                                                              style: const TextStyle(
                                                                color: Color(0xFF673AB7),
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 12),
                                                          // اسم المريض
                                                          Expanded(
                                                            child: Text(
                                                              patientName,
                                                              textAlign: TextAlign.right,
                                                              style: const TextStyle(
                                                                fontWeight: FontWeight.w500,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
