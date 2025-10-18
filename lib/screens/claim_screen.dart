import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClaimScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const ClaimScreen({super.key, required this.labId, required this.labName});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  }

  CollectionReference<Map<String, dynamic>> get _patientsCol =>
      FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients');

  int _parsePrice(dynamic p) {
    if (p is int) return p;
    if (p is num) return p.toInt();
    if (p is String) return int.tryParse(p) ?? 0;
    return 0;
  }

  Future<int> _getTotalForPatient(String patientId) async {
    final snap =
        await _patientsCol.doc(patientId).collection('lab_request').get();
    int total = 0;
    for (final d in snap.docs) {
      total += _parsePrice(d.data()['price']);
    }
    return total;
  }

  Future<Map<String, dynamic>> _getClaimSummary() async {
    final docs =
        await _patientsCol.where('labId', isEqualTo: widget.labId).get();

    // Filter by date range
    final filteredDocs =
        docs.docs.where((d) {
          final v = d.data()['createdAt'];
          DateTime? dt;
          if (v is Timestamp) dt = v.toDate();
          if (v is int) dt = DateTime.fromMillisecondsSinceEpoch(v);
          if (v is String) {
            final parsed = DateTime.tryParse(v);
            if (parsed != null) dt = parsed;
          }
          if (dt == null) return false;
          return !dt.isBefore(_startDate) && !dt.isAfter(_endDate);
        }).toList();

    int totalAmount = 0;
    for (final doc in filteredDocs) {
      final patientTotal = await _getTotalForPatient(doc.id);
      totalAmount += patientTotal;
    }

    return {
      'totalAmount': totalAmount,
      'patientCount': filteredDocs.length,
      'patients': filteredDocs,
    };
  }

  Future<void> _showDetailsDialog(String patientId, String patientName) async {
    final reqSnap =
        await _patientsCol.doc(patientId).collection('lab_request').get();
    int total = 0;
    final items = <Map<String, dynamic>>[];
    for (final d in reqSnap.docs) {
      final data = d.data();
      final name = data['name']?.toString() ?? '';
      final int price = _parsePrice(data['price']);
      total += price;
      items.add({'name': name, 'price': price});
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('تفاصيل مطالبة: $patientName'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (items.isEmpty) const Text('لا توجد فحوصات'),
                    if (items.isNotEmpty)
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (_, i) {
                            final it = items[i];
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(it['name']?.toString() ?? ''),
                                ),
                                Text('${it['price'] ?? 0}'),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الإجمالي',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$total',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickDateRange() async {
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;
    bool selectingStart = true; // أول ضغطة = بداية، الثانية = نهاية

    await showDialog(
      context: context,
      builder:
          (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setLocal) {
                return AlertDialog(
                  title: const Text('اختر الفترة'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: const Color(0xFF673AB7),
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: CalendarDatePicker(
                            initialDate: selectingStart ? tempStart : tempEnd,
                            firstDate: DateTime(2024, 1, 1),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            currentDate: DateTime.now(),
                            onDateChanged: (d) {
                              setLocal(() {
                                final picked = DateTime(d.year, d.month, d.day);
                                if (selectingStart) {
                                  tempStart = picked;
                                  tempEnd = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    23,
                                    59,
                                    59,
                                    999,
                                  );
                                  selectingStart =
                                      false; // التالية ستكون للنهاية
                                } else {
                                  if (picked.isBefore(tempStart)) {
                                    // إذا اختيرت نهاية قبل البداية: اجعلها بداية وابدأ من جديد
                                    tempStart = picked;
                                    tempEnd = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      23,
                                      59,
                                      59,
                                      999,
                                    );
                                    selectingStart = false;
                                  } else {
                                    tempEnd = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      23,
                                      59,
                                      59,
                                      999,
                                    );
                                    selectingStart = true; // إكمال التحديد
                                  }
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('من: ${_fmt(tempStart)}'),
                            Text('إلى: ${_fmt(tempEnd)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673AB7),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _startDate = DateTime(
                            tempStart.year,
                            tempStart.month,
                            tempStart.day,
                          );
                          _endDate = DateTime(
                            tempEnd.year,
                            tempEnd.month,
                            tempEnd.day,
                            23,
                            59,
                            59,
                            999,
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('موافق'),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatPrice(int price) {
    final str = price.toString();
    return str.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'المطالبة',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
          leading:
              _showDetails
                  ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _showDetails = false;
                      });
                    },
                    tooltip: 'العودة للملخص',
                  )
                  : null,
          actions: [
            IconButton(
              tooltip: 'اختيار الفترة',
              icon: const Icon(Icons.date_range, color: Colors.white),
              onPressed: _pickDateRange,
            ),
          ],
        ),
        body:Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey.shade200,
                  const Color(0xFF673AB7).withOpacity(0.2),
                  const Color(0xFF673AB7).withOpacity(0.35),
                ],
              ),
            ),
            width: double.infinity,
            height: double.infinity,
            child: SafeArea(
          child: _showDetails ? _buildPatientsList() : _buildSummaryView(),
        ),
      ),),
    );
  }

  Widget _buildSummaryView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getClaimSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        final totalAmount = data['totalAmount'] as int;
        final patientCount = data['patientCount'] as int;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lab name and date range
              Text(
                'ملخص المطالبة ${widget.labName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF673AB7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'الفترة من ${_fmt(_startDate)} إلى ${_fmt(_endDate)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Total amount - large and bold with underline
              Center(
                child: Column(
                  children: [
                    Text(
                      'المبلغ ${_formatPrice(totalAmount)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 0, 5, 12),
                      ),
                    ),
                    Container(
                      width: 200,
                      height: 2,
                      color: const Color(0xFF673AB7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Patient count
              Center(
                child: Text(
                  'عدد المرضى: $patientCount',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Spacer(),

              // Details button
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showDetails = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF673AB7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

                child: const Text(
                  'عرض التفاصيل',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _patientsCol.where('labId', isEqualTo: widget.labId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        // Filter by date range
        final docs =
            snap.data!.docs.where((d) {
                final v = d.data()['createdAt'];
                DateTime? dt;
                if (v is Timestamp) dt = v.toDate();
                if (v is int) dt = DateTime.fromMillisecondsSinceEpoch(v);
                if (v is String) {
                  final parsed = DateTime.tryParse(v);
                  if (parsed != null) dt = parsed;
                }
                if (dt == null) return false;
                return !dt.isBefore(_startDate) && !dt.isAfter(_endDate);
              }).toList()
              ..sort((a, b) {
                final va = a.data()['createdAt'];
                final vb = b.data()['createdAt'];
                DateTime? da;
                DateTime? db;
                if (va is Timestamp) da = va.toDate();
                if (va is int) da = DateTime.fromMillisecondsSinceEpoch(va);
                if (va is String) da = DateTime.tryParse(va);
                if (vb is Timestamp) db = vb.toDate();
                if (vb is int) db = DateTime.fromMillisecondsSinceEpoch(vb);
                if (vb is String) db = DateTime.tryParse(vb);
                final ta = da?.millisecondsSinceEpoch ?? 0;
                final tb = db?.millisecondsSinceEpoch ?? 0;
                return tb.compareTo(ta);
              });

        if (docs.isEmpty)
          return const Center(child: Text('لا توجد نتائج للفترة المحددة'));

        return ListView.separated(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();
            final name = data['name']?.toString() ?? '';
            final displayIndex = i + 1;

            return Card(
              child: ListTile(
                title: Text(
                  '$displayIndex. $name',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: FutureBuilder<int>(
                  future: _getTotalForPatient(d.id),
                  builder: (_, totalSnap) {
                    if (!totalSnap.hasData) {
                      return const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Text(
                      _formatPrice(totalSnap.data!),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
                onTap: () => _showDetailsDialog(d.id, name),
              ),
            );
          },
        );
      },
    );
  }
}
