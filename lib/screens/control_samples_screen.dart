import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/order_request_screen.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';

class ControlSamplesScreen extends StatefulWidget {
  const ControlSamplesScreen({super.key});

  @override
  State<ControlSamplesScreen> createState() => _ControlSamplesScreenState();
}

class _ControlSamplesScreenState extends State<ControlSamplesScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<String?> _getUserType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userType');
    } catch (_) {
      return null;
    }
  }

  Future<void> _logoutDelivery(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      cancelText: 'إلغاء',
      confirmText: 'موافق',
      helpText: 'اختر التاريخ',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF673AB7),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // جلب المرضى حسب التاريخ المحدد وجمعهم حسب المعمل
  Future<Map<String, List<Map<String, dynamic>>>>
  _getLabsWithPatientsToday() async {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
    );

    final snapshot =
        await FirebaseFirestore.instance
            .collection('labToLap')
            .doc('global')
            .collection('patients')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'createdAt',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .get();

    final allPatients =
        snapshot.docs.map((doc) {
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
  Future<Map<String, String>> _getLabInfo(String labId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(labId)
              .get();
      final data = doc.data();
      return {
        'name': data?['name'] ?? 'غير معروف',
        'address': data?['address'] ?? 'بدون عنوان',
      };
    } catch (_) {
      return {'name': 'غير معروف', 'address': 'بدون عنوان'};
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
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              onPressed: _selectDate,
              tooltip: 'اختيار التاريخ',
            ),
            FutureBuilder<String?>(
              future: _getUserType(),
              builder: (context, snapshot) {
                final userType = snapshot.data;
                if (userType == 'userDelivery') {
                  return IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'تسجيل الخروج',
                    onPressed: () => _logoutDelivery(context),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body:SafeArea(child:  Column(
          children: [
            // عرض التاريخ
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'التاريخ: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            // قائمة المعامل
            Expanded(
              child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
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
                    return const Center(
                      child: Text('لا توجد عينات مضافة في هذا التاريخ.'),
                    );
                  }

                  final labIds = labsMap.keys.toList();

                  return ListView.builder(
                    itemCount: labIds.length,
                    itemBuilder: (context, index) {
                      final labId = labIds[index];
                      final patientsList = labsMap[labId]!;
                      final patientCount = patientsList.length;

                      return FutureBuilder<Map<String, String>>(
                        future: _getLabInfo(labId),
                        builder: (context, labSnapshot) {
                          final labName =
                              labSnapshot.data?['name'] ?? 'جاري التحميل...';
                          final address =
                              labSnapshot.data?['address'] ?? 'بدون عنوان';

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Card(
                              color: const Color.fromARGB(255, 253, 253, 253),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                title: Text(
                                  labName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  address,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF673AB7),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    '$patientCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                    ),
                                    builder:
                                        (context) => DraggableScrollableSheet(
                                          expand: false,
                                          initialChildSize: 0.6,
                                          minChildSize: 0.4,
                                          maxChildSize: 0.9,
                                          builder: (context, scrollController) {
                                            return Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'عينات $labName',
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Expanded(
                                                    child: Directionality(
                                                      textDirection:
                                                          TextDirection.rtl,
                                                      child: ListView.builder(
                                                        controller:
                                                            scrollController,
                                                        itemCount:
                                                            patientsList.length,
                                                        itemBuilder: (_, i) {
                                                          final p =
                                                              patientsList[i];
                                                          final patientName =
                                                              p['name'] ??
                                                              'بدون اسم';
                                                          final patientId =
                                                              p['id']
                                                                  ?.toString() ??
                                                              'غير متوفر';
                                                          final patientDocId =
                                                              p['docId']
                                                                  ?.toString() ??
                                                              '';
                                                          final bool received =
                                                              (p['order_receieved'] ==
                                                                  true);
                                                          final String status =
                                                              p['status']
                                                                  ?.toString() ??
                                                              'pending';
                                                          final bool
                                                          isCancelled =
                                                              status ==
                                                              'cancelled';

                                                          return Card(
                                                            elevation: 2,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                            ),
                                                            margin:
                                                                const EdgeInsets.symmetric(
                                                                  vertical: 8,
                                                                ),
                                                            child: InkWell(
                                                              onTap: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder:
                                                                        (
                                                                          _,
                                                                        ) => OrderRequestScreen(
                                                                          labId:
                                                                              labId,
                                                                          labName:
                                                                              labName,
                                                                          patientDocId:
                                                                              patientDocId,
                                                                        ),
                                                                  ),
                                                                );
                                                              },
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          12,
                                                                    ),
                                                                child: Row(
                                                                  children: [
                                                                    // ✅ مربع الكود
                                                                    Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            isCancelled
                                                                                ? Colors.white
                                                                                : received
                                                                                ? Colors.white
                                                                                : Colors.white,
                                                                        border: Border.all(
                                                                          color:
                                                                              isCancelled
                                                                                  ? Colors.red
                                                                                  : received
                                                                                  ? Colors.green
                                                                                  : const Color(
                                                                                    0xFF673AB7,
                                                                                  ),
                                                                          width:
                                                                              2,
                                                                        ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        patientId,
                                                                        style: const TextStyle(
                                                                          color: Color(
                                                                            0xFF673AB7,
                                                                          ),
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 12,
                                                                    ),
                                                                    // اسم المريض
                                                                    Expanded(
                                                                      child: Text(
                                                                        patientName,
                                                                        textAlign:
                                                                            TextAlign.right,
                                                                        style: const TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                          fontSize:
                                                                              16,
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
          ],
        ),
      ),),
    );
  }
}
