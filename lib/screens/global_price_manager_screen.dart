import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ضروري لاستخدام الـ Formatters

class GlobalPriceManagerScreen extends StatefulWidget {
  const GlobalPriceManagerScreen({super.key});

  @override
  State<GlobalPriceManagerScreen> createState() =>
      _GlobalPriceManagerScreenState();
}

class _GlobalPriceManagerScreenState extends State<GlobalPriceManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'تعديل الأسعار الموحد',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body:SafeArea(child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ابحث عن فحص...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF673AB7),
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('labToLap')
                        .limit(1)
                        .snapshots(),
                builder: (context, labSnapshot) {
                  if (labSnapshot.hasError)
                    return const Center(child: Text('حدث خطأ ما'));
                  if (!labSnapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  if (labSnapshot.data!.docs.isEmpty)
                    return const Center(child: Text('لا توجد معامل حالياً'));

                  String firstLabId = labSnapshot.data!.docs.first.id;

                  return StreamBuilder<QuerySnapshot>(
                    stream:
                        FirebaseFirestore.instance
                            .collection('labToLap')
                            .doc(firstLabId)
                            .collection('pricelist')
                            .snapshots(),
                    builder: (context, testSnapshot) {
                      if (!testSnapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final docs =
                          testSnapshot.data!.docs.where((d) {
                            final name =
                                (d['name']?.toString() ?? '').toLowerCase();
                            return name.contains(_searchQuery);
                          }).toList();

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'لا توجد نتائج مطابقة للبحث',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: docs.length,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemBuilder: (context, index) {
                          var testData =
                              docs[index].data() as Map<String, dynamic>;
                          String testId = docs[index].id;

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),

                              title: Text(
                                testData['name'] ?? 'بدون اسم',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'السعر الحالي: ${testData['price']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.edit_rounded,
                                color: Color(0xFF673AB7),
                              ),
                              onTap:
                                  () => _showUpdateDialog(
                                    context,
                                    testId,
                                    testData['name'] ?? '',
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
      ),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, String testId, String testName) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text('تعديل سعر $testName الموحد'),
              content: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Text(
                    'سيتم تغيير السعر في جميع المعامل المسجلة فوراً',
                    style: TextStyle(fontSize: 13, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    // --- التعديل هنا ---
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter
                          .digitsOnly, // يمنع النقطة والفواصل والكسور نهائياً
                    ],
                    // -------------------
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'السعر الجديد',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // نحول النص إلى رقم (سيكون دائماً صحيحاً بسبب الـ Formatter)
                    int? newPrice = int.tryParse(controller.text);
                    if (newPrice != null) {
                      _updateAllLabs(context, testId, newPrice.toInt());
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')),
                      );
                    }
                  },
                  child: const Text(
                    'تحديث في كل المعامل',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _updateAllLabs(
    BuildContext context,
    String testId,
    int price,
  ) async {
    final firestore = FirebaseFirestore.instance;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final labs = await firestore.collection('labToLap').get();
      WriteBatch batch = firestore.batch();

      for (var lab in labs.docs) {
        DocumentReference ref = firestore
            .collection('labToLap')
            .doc(lab.id)
            .collection('pricelist')
            .doc(testId);

        batch.set(ref, {'price': price}, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث السعر بنجاح في جميع المعامل'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التحديث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
