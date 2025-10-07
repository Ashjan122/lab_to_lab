import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LabPriceListScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const LabPriceListScreen({super.key, required this.labId, required this.labName});

  @override
  State<LabPriceListScreen> createState() => _LabPriceListScreenState();
}

class _LabPriceListScreenState extends State<LabPriceListScreen> {
   final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  String? _editingId;
  String _searchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _searchController.dispose();
    super.dispose();
  }
 CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance
      .collection('labToLap')
      .doc(widget.labId)
      .collection('pricelist');

  // Removed _startAdd method - no longer adding new tests

  void _startEdit(String id, Map<String, dynamic> data) {
    setState(() {
      _editingId = id;
    });
    _nameController.text = data['name']?.toString() ?? '';
    _priceController.text = (data['price']?.toString() ?? '');
    _showFormSheet();
  }

  
  

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final num? priceNum = num.tryParse(_priceController.text.trim());
      // Only update price, keep existing name
      await _col.doc(_editingId).update({'price': priceNum});
      if (!mounted) return;
      Navigator.pop(context); // close sheet
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث السعر'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFormSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit, color: Color.fromARGB(255, 90, 138, 201)),
                      const SizedBox(width: 8),
                      const Text('تعديل السعر', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم الفحص', border: OutlineInputBorder()),
                    enabled: false, // Disable name editing
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder(), hintText: 'مثال: 1500'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'أدخل السعر';
                      return num.tryParse(v.trim()) == null ? 'أدخل رقماً صحيحاً' : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 90, 138, 201), foregroundColor: Colors.white),
                      child: _submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('تحديث السعر'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return  Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Scaffold(
        appBar: AppBar(
          title: Text('قائمة الأسعار - ${widget.labName}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          // Removed add button - no longer adding new tests
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                textDirection: TextDirection.rtl,

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
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _col.snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('خطأ: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snap.data!.docs;
                  // Filter by search query
                  final filtered = all.where((d) {
                    final name = (d.data()['name']?.toString() ?? '').toLowerCase();
                    if (_searchQuery.isEmpty) return true;
                    return name.contains(_searchQuery);
                  }).toList();
                  // Sort by numeric id ascending (like DB). Items without numeric id go last by doc id
                  filtered.sort((a, b) {
                    final ida = a.data()['id'];
                    final idb = b.data()['id'];
                    final ia = (ida is num) ? ida.toInt() : int.tryParse('${ida ?? ''}');
                    final ib = (idb is num) ? idb.toInt() : int.tryParse('${idb ?? ''}');
                    if (ia != null && ib != null) return ia.compareTo(ib);
                    if (ia != null) return -1; // with id first
                    if (ib != null) return 1;
                    return a.id.compareTo(b.id);
                  });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.price_change, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('لا توجد فحوصات', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = filtered[i];
                      final data = d.data();
                      final name = data['name']?.toString() ?? '';
                      final price = data['price'];
                      return Card(
                        child: ListTile(
                          title: 
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${price.toString()} SDG',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),),Expanded(child:
                              Text(name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.left,
                              overflow: TextOverflow.visible,
                              maxLines: 2,))
                            ],
                          ),
                         subtitle: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
  future: FirebaseFirestore.instance
      .collection('labToLap')
      .doc('global')
      .collection('cashPriceList')
      .doc(d.id) // لازم doc.id يكون نفس id المستخدم في cashPriceList
      .get(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const SizedBox(); // أو Spinner بسيط لو حابة
    }

    if (!snapshot.hasData || !snapshot.data!.exists) {
      return const SizedBox(); // ما في سعر نقدي
    }

    final cashPrice = snapshot.data!.data()?['price'];

    if (cashPrice == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$cashPrice SDG',
        style: const TextStyle(
          color: Colors.grey,
          decoration: TextDecoration.lineThrough,
          decorationThickness: 2,
          height: 2,
          fontSize: 13,
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
      ),
    );
  }
}