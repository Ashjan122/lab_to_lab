import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_patient_result_detail_screen.dart';

class LabSelectTestsScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final String patientId;
  const LabSelectTestsScreen({super.key, required this.labId, required this.labName, required this.patientId});

  @override
  State<LabSelectTestsScreen> createState() => _LabSelectTestsScreenState();
}

class _LabSelectTestsScreenState extends State<LabSelectTestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = <String>{};
  final Set<String> _existingTestIds = <String>{}; // Track existing tests
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingTests();
  }
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<void> _loadExistingTests() async {
    try {
      final reqCol = FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(widget.patientId)
          .collection('lab_request');

      final snapshot = await reqCol.get();
      final existingIds = snapshot.docs.map((doc) => doc.data()['testId'] as String).toSet();
      
      if (mounted) {
        setState(() {
          _existingTestIds.addAll(existingIds);
          _selectedIds.addAll(existingIds); // Mark existing tests as selected
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفحوصات الموجودة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  CollectionReference<Map<String, dynamic>> get _priceCol => FirebaseFirestore.instance
      .collection('labToLap')
      .doc(widget.labId)
      .collection('pricelist');

  Future<void> _saveSelection(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final reqCol = FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(widget.patientId)
          .collection('lab_request');

      // Only save newly selected tests (not existing ones)
      final newSelectedIds = _selectedIds.difference(_existingTestIds);
      final selectedDocs = docs.where((d) => newSelectedIds.contains(d.id));
      
      // Aggregate for notification
      final List<String> testNames = [];
      num totalPrice = 0;

      for (final d in selectedDocs) {
        final data = d.data();
        final reqDocRef = reqCol.doc();
        batch.set(reqDocRef, {
          'testId': d.id,
          'name': data['name'],
          'price': data['price'],
          'container_id': data['container_id'] ?? data['containerId'],
          'createdAt': FieldValue.serverTimestamp(),
        });

        final name = data['name']?.toString() ?? '';
        final priceDyn = data['price'];
        final priceNum = (priceDyn is num) ? priceDyn : (num.tryParse('$priceDyn') ?? 0);
        if (name.isNotEmpty) testNames.add(name);
        totalPrice += priceNum;
      }
      
      if (newSelectedIds.isNotEmpty) {
        await batch.commit();
        
        // Send notification (simple approach)
        try {
          // Fetch patient name
          final pSnap = await FirebaseFirestore.instance
              .collection('labToLap')
              .doc('global')
              .collection('patients')
              .doc(widget.patientId)
              .get();
          final patientName = pSnap.data()?['name']?.toString() ?? 'مريض';

          final String lab = (widget.labName).trim();
          final String title = lab.startsWith('معمل')
              ? 'مريض جديد في $lab'
              : 'مريض جديد في معمل $lab';
          final String body = 'اسم المريض: $patientName\nالفحوصات: ${testNames.join(', ')}\nالمبلغ: ${totalPrice.toStringAsFixed(0)}';

          await FirebaseFirestore.instance.collection('push_requests').add({
            'topic': 'lab_order',
            'title': title,
            'body': body,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {
          // ignore notification enqueue errors
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت إضافة ${newSelectedIds.length} فحص جديد'), backgroundColor: Colors.green),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد فحوصات جديدة لإضافتها'), backgroundColor: Colors.orange),
        );
      }
      
      // Navigate to results screen without clearing the entire stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LabPatientResultDetailScreen(
            labId: widget.labId,
            labName: widget.labName,
            patientDocId: widget.patientId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return  Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('اختيار الفحوصات - ${widget.labName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(_selectedIds.isEmpty ? '' : 'المحدد: ${_selectedIds.length}', style: const TextStyle(color: Colors.white)),
              ),
            ),
            IconButton(
              tooltip: 'حفظ',
              onPressed: _saving ? null : () {},
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.save, color: Colors.white),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                textDirection: TextDirection.ltr,
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  labelText: 'بحث باسم الفحص',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _priceCol.snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      final docs = snap.data!.docs.where((d) {
                        final n = (d.data()['name']?.toString() ?? '').toLowerCase();
                        if (_searchQuery.isEmpty) return true;
                        return n.contains(_searchQuery);
                      }).toList();
                      // sort by numeric id ascending; items without valid id go last by doc id
                      docs.sort((a, b) {
                        final ida = a.data()['id'];
                        final idb = b.data()['id'];
                        final ia = (ida is num) ? ida.toInt() : int.tryParse('${ida ?? ''}');
                        final ib = (idb is num) ? idb.toInt() : int.tryParse('${idb ?? ''}');
                        if (ia != null && ib != null) return ia.compareTo(ib);
                        if (ia != null) return -1;
                        if (ib != null) return 1;
                        return a.id.compareTo(b.id);
                      });

                      return ListView.separated(
                        itemCount: docs.length,
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final d = docs[i];
                          final data = d.data();
                          final name = data['name']?.toString() ?? '';
                          final price = data['price'];
                          final selected = _selectedIds.contains(d.id);
                          final isExisting = _existingTestIds.contains(d.id);
                          
                          return Card(
                            color: isExisting ? Colors.grey[100] : null,
                            child: CheckboxListTile(
                              value: selected,
                              onChanged: (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(d.id);
                                  } else {
                                    _selectedIds.remove(d.id);
                                  }
                                });
                              },
                              title: Text(
                                name, 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExisting ? Colors.grey[600] : null,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('السعر: ${price ?? 0}'),
                                  if (isExisting) 
                                    const Text(
                                      'موجود مسبقاً', 
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            final snap = await _priceCol.get();
                            final allDocs = snap.docs;
                            // save to lab_request
                            await _saveSelection(allDocs);
                          },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 90, 138, 201), foregroundColor: Colors.white),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('حفظ '),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}