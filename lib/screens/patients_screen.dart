import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';

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

  Stream<QuerySnapshot<Map<String, dynamic>>> getPatientsStream() {
    final col = FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients');

    if (_searchQuery.isNotEmpty) {
      // لو في بحث: رجّع كل المرضى بدون فلترة بالتاريخ
      return col.orderBy('createdAt', descending: true).snapshots();
    } else {
      // لو مافي بحث: فلتر بالتاريخ
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

      return col
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Future<String> _getLabName(String labId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
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

  void _showStatusDialog(BuildContext context, Map<String, dynamic> data) {
    final bool received = data['order_receieved'] == true;
    final String receivedBy = data['order_receieved_by_name'] ?? '';
    final Timestamp? receivedAt = data['order_receieved_at'];

    final bool delivered = data['sample_delivered'] == true;
    final String? deliveredAtStr = data['delivered_at'];
    DateTime? deliveredAt;
    if (deliveredAtStr != null && deliveredAtStr.isNotEmpty) {
      deliveredAt = DateTime.tryParse(deliveredAtStr);
    }

    final String? pdfUrl = data['pdf_url'];
    final bool resultCompleted = pdfUrl != null && pdfUrl.isNotEmpty;
    final Timestamp? resultUpdatedAt = data['result_updated_at'];

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('تفاصيل حالة الطلب', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (received)
                  _buildStatusRow(
                    title: 'تم الاستلام من قبل $receivedBy',
                    time: _formatTimestamp(receivedAt),
                  ),
                if (delivered && deliveredAt != null)
                  _buildStatusRow(
                    title: 'تم توصيل العينة',
                    time: _formatDateTime(deliveredAt),
                  ),
                if (resultCompleted && resultUpdatedAt != null)
                  _buildStatusRow(
                    title: 'اكتملت النتيجة',
                    time: _formatTimestamp(resultUpdatedAt),
                  ),
                if (!received && !delivered && !resultCompleted)
                  const Text('لا توجد معلومات عن حالة الطلب.'),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('إغلاق'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
    );
  }

  Widget _buildStatusRow({required String title, required String time}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  // لتحويل Timestamp إلى نص
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year} - ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  // لتحويل DateTime إلى نص
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${_twoDigits(dateTime.day)}/${_twoDigits(dateTime.month)}/${dateTime.year} - ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  // دالة مساعدة لتنسيق الأرقام: 1 => 01
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  Future<bool> _isDeliveryUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('userType') == 'userDelivery';
    } catch (_) {
      return false;
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

  @override
  Widget build(BuildContext context) {

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'المرضى',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
            tooltip: 'اختيار التاريخ',
          ),
          actions: [
            FutureBuilder<bool>(
              future: _isDeliveryUser(),
              builder: (context, snapshot) {
                final isDelivery = snapshot.data == true;
                if (isDelivery) {
                  return IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'تسجيل الخروج',
                    onPressed: () => _logoutDelivery(context),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                );
              },
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
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Patients list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: getPatientsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('خطأ: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Filter by search query
                  final filteredDocs =
                      docs.where((doc) {
                        final data = doc.data();
                        final patientName =
                            data['name']?.toString().toLowerCase() ?? '';
                        return patientName.contains(_searchQuery);
                      }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'لا توجد نتائج للبحث'
                            : 'لا يوجد مرضى في هذا التاريخ',
                      ),
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
                      final String status = data['status']?.toString() ?? 'pending';
                      final bool isCancelled = status == 'cancelled';

                      return Card(
                        elevation: 2,
                        color: isCancelled ? Colors.red.withOpacity(0.1) : Colors.white,
                        child: FutureBuilder<String>(
                          future: _getLabName(labId),
                          builder: (context, labSnapshot) {
                            final labName =
                                labSnapshot.data ?? 'جاري التحميل...';

                            return ListTile(
                              leading: IntrinsicWidth(
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minWidth: 0,
                                    minHeight: 28,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCancelled
                                        ? Colors.red.withOpacity(0.2)
                                        : received
                                            ? Colors.green
                                            : Colors.white,
                                    border: Border.all(
                                      color: isCancelled
                                          ? Colors.red
                                          : received
                                              ? Colors.green
                                              : const Color.fromARGB(
                                                255,
                                                90,
                                                138,
                                                201,
                                              ),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      patientId,
                                      style: TextStyle(
                                        color: isCancelled
                                            ? Colors.red
                                            : received
                                                ? Colors.white
                                                : const Color.fromARGB(
                                                  255,
                                                  90,
                                                  138,
                                                  201,
                                                ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      patientName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  if (isCancelled)
                                    Text(
                                      '(ملغي)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                labName,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              onTap:
                                  labSnapshot.hasData
                                      ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => OrderRequestScreen(
                                                  labId:
                                                      labId.isNotEmpty
                                                          ? labId
                                                          : 'global',
                                                  labName: labName,
                                                  patientDocId: patientDocId,
                                                ),
                                          ),
                                        );
                                      }
                                      : null, // امنع التنقل إذا labName لم يتم تحميله بعد
                              onLongPress: () {
                                _showStatusDialog(context, data);
                              },
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
