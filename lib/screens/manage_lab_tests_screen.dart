import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageLabTestsScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const ManageLabTestsScreen({
    super.key,
    required this.labId,
    required this.labName,
  });

  @override
  State<ManageLabTestsScreen> createState() => _ManageLabTestsScreenState();
}

class _ManageLabTestsScreenState extends State<ManageLabTestsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('labToLap')
      .doc(widget.labId)
      .collection('pricelist');

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'إدارة التحاليل - ${widget.labName}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              tooltip: 'تحديد/إلغاء تحديد الكل',
              onPressed: () async {
                try {
                  final snapshot = await _col.get();
                  final allDocs = snapshot.docs;

                  // نتحقق هل هناك أي فحوصات مخفية
                  final anyHidden = allDocs.any(
                    (d) => d.data()['hidden'] == true,
                  );

                  // إنشاء Batch
                  final batch = FirebaseFirestore.instance.batch();

                  // تحديث كل المستندات في Batch
                  for (final doc in allDocs) {
                    batch.set(doc.reference, {
                      'hidden': !anyHidden,
                    }, SetOptions(merge: true));
                  }

                  // تنفيذ Batch دفعة واحدة
                  await batch.commit();

                  // إعادة بناء الشاشة
                  if (mounted) setState(() {});
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),

        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _search,
                onChanged:
                    (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  labelText: 'بحث باسم الفحص',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // هنا نجعل Firestore يعيد جلب البيانات
                  // بما أننا نستخدم StreamBuilder، يمكننا فقط عمل setState لإعادة البناء
                  setState(() {});
                },
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _col.snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError)
                      return Center(child: Text('خطأ: ${snap.error}'));
                    if (!snap.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final docs =
                        snap.data!.docs.where((d) {
                            final name =
                                (d.data()['name']?.toString() ?? '')
                                    .toLowerCase();
                            return _query.isEmpty || name.contains(_query);
                          }).toList()
                          ..sort((a, b) {
                            final orderA = a.data()['order'];
                            final orderB = b.data()['order'];
                            final idA = a.data()['id'];
                            final idB = b.data()['id'];
                            final hasOrderA = orderA is num && orderA > 0;
                            final hasOrderB = orderB is num && orderB > 0;
                            if (hasOrderA && hasOrderB)
                              return orderA.compareTo(orderB);
                            if (hasOrderA) return -1;
                            if (hasOrderB) return 1;
                            final hasIdA = idA is num && idA > 0;
                            final hasIdB = idB is num && idB > 0;
                            if (hasIdA && hasIdB) return idA.compareTo(idB);
                            if (hasIdA) return -1;
                            if (hasIdB) return 1;
                            return 0;
                          });

                    if (docs.isEmpty)
                      return const Center(child: Text('لا توجد فحوصات'));

                    return ListView.separated(
                      itemCount: docs.length,
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        final data = d.data();
                        final name = data['name']?.toString() ?? '';

                        final hasHiddenKey = data.containsKey('hidden');
                        final hidden =
                            data['hidden'] ==
                            true; // if missing we'll set to true below
                        if (!hasHiddenKey) {
                          WidgetsBinding.instance.addPostFrameCallback((
                            _,
                          ) async {
                            try {
                              await _col.doc(d.id).set({
                                'hidden': true,
                              }, SetOptions(merge: true));
                            } catch (_) {}
                          });
                        }

                        final isChecked = !hidden; // checked means visible

                        return Card(
                          child: ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: Checkbox(
                              value: isChecked,
                              onChanged: (v) async {
                                final nextChecked = v == true;
                                try {
                                  await _col.doc(d.id).set({
                                    'hidden': !nextChecked,
                                  }, SetOptions(merge: true));
                                  if (mounted) setState(() {});
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('خطأ: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
