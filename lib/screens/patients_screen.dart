import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
 
import 'package:lab_to_lab_admin/screens/order_request_screen.dart';

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
                      

                      return Card(
                        elevation: 2,
                        color: Colors.white,
                        child: ListTile(
                          leading: Container(
                             constraints: const BoxConstraints(
                                  minWidth: 40, // الحد الأدنى للعرض
                                  maxWidth: 120, // 👈 يسمح بعرض يصل حتى 6 أرقام
                                  minHeight: 40,
                                     ), 
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color.fromARGB(255, 90, 138, 201),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
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
                              final bool received = (data['order_receieved'] == true);
                              final String receivedBy = data['order_receieved_by_name']?.toString() ?? '';
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ' $labName',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (received && receivedBy.isNotEmpty)
                                    const SizedBox(height: 4),
                                  if (received && receivedBy.isNotEmpty)
                                    Text(
                                      'تم الاستلام من قبل $receivedBy',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              );
                            },
                           
                          ),
                          
                          trailing: null,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderRequestScreen(
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
