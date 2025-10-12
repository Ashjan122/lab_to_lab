import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_dashboard_screen.dart';

import 'package:lab_to_lab_admin/screens/lab_patient_result_detail_screen.dart';

class LabResultsPatientsScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const LabResultsPatientsScreen({
    super.key,
    required this.labId,
    required this.labName,
  });
  @override
  State<LabResultsPatientsScreen> createState() =>
      _LabResultsPatientsScreenState();
}

class _LabResultsPatientsScreenState extends State<LabResultsPatientsScreen> {
  late DateTime _selectedDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSameDay(Timestamp? ts, DateTime day) {
    if (ts == null) return false;
    final dt = ts.toDate();
    return dt.year == day.year && dt.month == day.month && dt.day == day.day;
  }

  Widget _buildProgressBar(Map<String, dynamic> data) {
    final orderReceived = data['order_receieved'] == true;
    final sampledDelivered = data['sample_delivered'] == true;
    final pdfUrl = data['pdf_url']?.toString();
    final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty;

    double progress = 0.0;
    Color progressColor = Colors.grey;

    if (orderReceived) {
      progress = 0.3; // 30%
      progressColor = Colors.blue;
    }

    if (sampledDelivered) {
      progress = 0.6; // 60%
      progressColor = Colors.orange;
    }

    if (hasPdf) {
      progress = 1.0; // 100%
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getProgressText(orderReceived, sampledDelivered, hasPdf),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 6,
        ),
      ],
    );
  }

  String _getProgressText(
    bool orderReceived,
    bool sampledDelivered,
    bool hasPdf,
  ) {
    if (hasPdf) {
      return 'اكتملت النتيجة';
    } else if (sampledDelivered) {
      return 'تم توصيل العينات';
    } else if (orderReceived) {
      return 'تم استلام الطلب';
    } else {
      return ' في انتظار المندوب';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر التاريخ',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'مرضى ${widget.labName}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          leading: IconButton(
            tooltip: 'اختيار التاريخ',
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _pickDate,
          ),

          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () {
                // الرجوع إلى لوحة تحكم المعمل مباشرة
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => LabDashboardScreen(
                          labId: widget.labId,
                          labName: widget.labName,
                        ),
                  ),
                  (route) => false,
                );
              },
              tooltip: 'الرجوع إلى لوحة المعمل',
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
                stream: col.where('labId', isEqualTo: widget.labId).snapshots(),
                builder: (context, snap) {
                  if (snap.hasError)
                    return Center(child: Text('خطأ: ${snap.error}'));
                  if (!snap.hasData)
                    return const Center(child: CircularProgressIndicator());

                  // فلترة حسب تاريخ اليوم المحدد
                  final allDocs = snap.data!.docs;

                  List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered =
                      [];

                  if (_searchQuery.isNotEmpty) {
                    // لو فيه بحث: تجاهل التاريخ وابحث في الكل
                    filtered =
                        allDocs.where((doc) {
                          final data = doc.data();
                          final patientName =
                              data['name']?.toString().toLowerCase() ?? '';
                          return patientName.contains(_searchQuery);
                        }).toList();
                  } else {
                    // لو ما فيه بحث: فلتر على حسب التاريخ
                    filtered =
                        allDocs.where((doc) {
                          final m = doc.data();
                          final ts = m['createdAt'];
                          final t = (ts is Timestamp) ? ts : null;
                          return _isSameDay(t, _selectedDate);
                        }).toList();
                  }

                  // ترتيب تنازلي حسب createdAt
                  filtered.sort((a, b) {
                    final aTs = a.data()['createdAt'];
                    final bTs = b.data()['createdAt'];
                    final aT = (aTs is Timestamp) ? aTs : null;
                    final bT = (bTs is Timestamp) ? bTs : null;
                    if (aT == null && bT == null) return 0;
                    if (aT == null) return 1;
                    if (bT == null) return -1;
                    return bT.compareTo(aT);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'لا توجد نتائج للبحث'
                            : 'لا توجد عينات لليوم المحدد',
                      ),
                    );
                  }

                  final perDayTotal = filtered.length;
                  return ListView.separated(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      final data = d.data();
                      final rawId = data['id'];
                      final patientCode =
                          (rawId is int)
                              ? rawId.toString()
                              : (int.tryParse('$rawId') ?? 0) > 0
                              ? '$rawId'
                              : d.id; // fallback للـ docId

                      final name = data['name']?.toString() ?? '';
                      final dayNumber =
                          perDayTotal - i; // رقم اليوم يبدأ من 1 لكل يوم
                      return Card(
                        child: ListTileTheme(
                          data: const ListTileThemeData(
                            horizontalTitleGap: 8,
                            minLeadingWidth: 0,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: ListTile(
                            minLeadingWidth: 0,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            leading: SizedBox(
                              width: 50,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Color.fromARGB(255, 90, 138, 201),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  patientCode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1976D2),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                _buildProgressBar(data),
                              ],
                            ),
                            /*trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: chipColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: chipColor, width: 1),
                              ),
                              child: Text(
                                status == 'comlated' ? 'completed' : status,
                                style: TextStyle(color: chipColor, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),*/
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => LabPatientResultDetailScreen(
                                        labId: widget.labId,
                                        labName: widget.labName,
                                        patientDocId: d.id,
                                      ),
                                ),
                              );
                            },
                          ),
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
