import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_patient_result_detail_screen.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              primary: Color.fromARGB(255, 90, 138, 201),
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

  Future<void> _receiveOrder(String patientDocId, String labId) async {
    try {
      // 1) Mark order as received
      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(patientDocId)
          .update({'order_receieved': true});

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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استلام الطلب'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في استلام الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المرضى', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              onPressed: _selectDate,
              tooltip: 'اختيار التاريخ',
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'البحث باسم المريض...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            // Date display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'التاريخ: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Patients list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('labToLap')
                    .doc('global')
                    .collection('patients')
                    .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('خطأ: ${snapshot.error}'));
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  // Filter by search query
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data();
                    final patientName = data['name']?.toString().toLowerCase() ?? '';
                    return patientName.contains(_searchQuery);
                  }).toList();
                  
                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(_searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا يوجد مرضى في هذا التاريخ'),
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredDocs.length,
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data();
                      final patientId = data['id']?.toString() ?? '';
                      final patientName = data['name']?.toString() ?? '';
                      final labId = data['labId']?.toString() ?? '';
                      final patientDocId = doc.id;
                      final bool received = (data['order_receieved'] == true);

                      return Card(
                        elevation: 2,
                        color: Colors.white,
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
                          
                          trailing: !received
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(255, 90, 138, 201),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: InkWell(
                                    onTap: () => _receiveOrder(patientDocId, labId),
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Text(
                                      'استلام الطلب',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'تم الاستلام',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LabPatientResultDetailScreen(
                                  labId: labId.isNotEmpty ? labId : 'global',
                                  labName: 'المعمل',
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
          ],
        ),
      ),
    );
  }
}
