import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LabPriceListScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final bool canEdit; // إذا true يسمح بالتعديل، افتراضياً false
  const LabPriceListScreen({
    super.key,
    required this.labId,
    required this.labName,
    this.canEdit = false,
  });

  @override
  State<LabPriceListScreen> createState() => _LabPriceListScreenState();
}

class _LabPriceListScreenState extends State<LabPriceListScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, AnimationController> _animationControllers = {};
  final TextEditingController _priceEditController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _priceEditController.dispose();
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('labToLap')
      .doc(widget.labId)
      .collection('pricelist');

  AnimationController _getAnimationController(String testId) {
    if (!_animationControllers.containsKey(testId)) {
      _animationControllers[testId] = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      // Start the animation immediately
      _animationControllers[testId]!.repeat(reverse: true);
    }
    return _animationControllers[testId]!;
  }
  Future<void> _editPriceDialog(String docId, String testName, num currentPrice) async {
    _priceEditController.text = currentPrice.toString();
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل السعر - $testName'),
          content: TextField(
            controller: _priceEditController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'السعر',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final v = _priceEditController.text.trim();
                final num? newPrice = num.tryParse(v);
                if (newPrice == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل سعراً صحيحاً'), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  await _col.doc(docId).update({'price': newPrice});
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7), foregroundColor: Colors.white),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConditionDialog(BuildContext context, String condition) {
  showDialog(
    context: context,
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl, // ⬅️ اجعل كل المحتوى من اليمين لليسار
      child: AlertDialog(
        title: const Text(
          'إرشادات الفحص',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF673AB7),
          ),
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            condition,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'حسناً',
              style: TextStyle(
                color: Color(0xFF673AB7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'قائمة الأسعار - ${widget.labName}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF673AB7),
            centerTitle: true,

            // Removed add button - no longer adding new tests
          ),
          body:SafeArea(child:  Container(
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
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  textDirection: TextDirection.rtl,

                  controller: _searchController,
                  onChanged:
                      (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
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
                    final filtered =
                        all.where((d) {
                          final name =
                              (d.data()['name']?.toString() ?? '')
                                  .toLowerCase();
                          final price = d.data()['price'];
                          // شرط البحث
                          final matchesSearch =
                              _searchQuery.isEmpty ||
                              name.contains(_searchQuery);

                          // استبعاد اللي السعر صفر أو null
                          final validPrice = price is num && price > 0;

                          // نظهر فقط الفحوصات التي hidden == false
                          final hidden = d.data()['hidden'];
                          final visible = hidden == false;

                          return matchesSearch && validPrice && visible;
                        }).toList();

                    // Sort by numeric id ascending (like DB). Items without numeric id go last by doc id
                    filtered.sort((a, b) {
                      final orderA = a.data()['order'];
                      final orderB = b.data()['order'];

                      final idA = a.data()['id'];
                      final idB = b.data()['id'];

                      final hasOrderA = orderA is num && orderA > 0;
                      final hasOrderB = orderB is num && orderB > 0;

                      if (hasOrderA && hasOrderB) {
                        return orderA.compareTo(orderB);
                      }
                      if (hasOrderA) return -1;
                      if (hasOrderB) return 1;

                      // ما في order ⇒ نرتب حسب id
                      final hasIdA = idA is num && idA > 0;
                      final hasIdB = idB is num && idB > 0;

                      if (hasIdA && hasIdB) {
                        return idA.compareTo(idB);
                      }
                      if (hasIdA) return -1;
                      if (hasIdB) return 1;

                      // ما في order ولا id ⇒ خلّيهم مكانهم
                      return 0;
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.price_change,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد فحوصات',
                              style: TextStyle(color: Colors.grey),
                            ),
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
                        final isUnavailable = data['available'] == false;
                        final conditions = data['conditions']?.toString().trim();
                        final hasConditions = conditions != null && conditions.isNotEmpty;

                        return Column(
                          children: [
                            Card(
                              color:
                                  isUnavailable
                                      ? Colors.grey.withOpacity(0.3)
                                      : null,
                              child: ListTile(
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${price.toString()} ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                       const SizedBox(width:5),
                                        if (hasConditions)
                                          GestureDetector(
                                            onTap: () {
                                              _showConditionDialog(
                                                context,
                                                conditions,
                                              );
                                            },
                                            child: AnimatedBuilder(
                                              animation: _getAnimationController(d.id),
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale: 1.0 + (_getAnimationController(d.id).value * 0.2),
                                                  child: Container(
                                                    width: 20,
                                                    height: 20,
                                                    margin: const EdgeInsets.only(left: 8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.orange.withOpacity(0.3),
                                                          blurRadius: 4,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                      Icons.info_outline,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.left,
                                        overflow: TextOverflow.visible,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Timer information
                                    if (data['timer'] != null && data['timer'] is num)
                                      Text(
                                        'الزمن المتوقع للفحص: ${data['timer']} ساعة',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    // Unavailable status
                                    if (isUnavailable)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 4),
                                        child: Text(
                                          'غير متاح',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: widget.canEdit
                                    ? IconButton(
                                        tooltip: 'تعديل السعر',
                                        icon: const Icon(Icons.edit, color: Color(0xFF673AB7)),
                                        onPressed: isUnavailable
                                            ? null
                                            : () {
                                                final num cur = (price is num) ? price : num.tryParse('$price') ?? 0;
                                                _editPriceDialog(d.id, name, cur);
                                              },
                                      )
                                    : null,

                                /* subtitle: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
),*/
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),),
        ),
        ),
    );
  }
}
