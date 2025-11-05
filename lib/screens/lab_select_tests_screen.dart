import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_patient_result_detail_screen.dart';
import 'package:http/http.dart' as http;

class LabSelectTestsScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final String patientId;
  final bool skipNotification; // إضافة معامل لتخطي الإشعار
  const LabSelectTestsScreen({
    super.key,
    required this.labId,
    required this.labName,
    required this.patientId,
    this.skipNotification = false,
  });

  @override
  State<LabSelectTestsScreen> createState() => _LabSelectTestsScreenState();
}

class _LabSelectTestsScreenState extends State<LabSelectTestsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = <String>{};
  final Set<String> _existingTestIds = <String>{}; // Track existing tests
  bool _saving = false;
  bool _loading = true;
  final Map<String, AnimationController> _animationControllers = {};

  @override
  void initState() {
    super.initState();
    _loadExistingTests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Dispose all animation controllers
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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


  Future<void> _loadExistingTests() async {
    try {
      final reqCol = FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(widget.patientId)
          .collection('lab_request');

      final snapshot = await reqCol.get();
      final existingIds =
          snapshot.docs.map((doc) => doc.data()['testId'] as String).toSet();

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
          SnackBar(
            content: Text('خطأ في تحميل الفحوصات الموجودة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  CollectionReference<Map<String, dynamic>> get _priceCol => FirebaseFirestore
      .instance
      .collection('labToLap')
      .doc(widget.labId)
      .collection('pricelist');

  Future<void> _saveSelection(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) async {
  setState(() => _saving = true);
  try {
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    final reqCol = FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients')
        .doc(widget.patientId)
        .collection('lab_request');

    // حذف الفحوصات التي أزيلت من التحديد
    final removedIds = _existingTestIds.difference(_selectedIds);
    for (final testId in removedIds) {
      final existingDocs = await reqCol.where('testId', isEqualTo: testId).get();
      for (final doc in existingDocs.docs) {
        batch.delete(doc.reference);
      }
    }

    // ✅ إضافة الفحوصات الجديدة فقط (تجنب المكررة)
    final newSelectedIds = _selectedIds.difference(_existingTestIds);
    final selectedDocs = docs.where((d) => newSelectedIds.contains(d.id));

    for (final d in selectedDocs) {
      final data = d.data();

      // ✅ تحقق محلياً لتجنب إدخال نفس الفحص مرتين
      if (_existingTestIds.contains(d.id)) {
        print('⚠️ الفحص ${data['name']} موجود مسبقاً، تم تخطيه.');
        continue;
      }

      final reqDocRef = reqCol.doc();
      batch.set(reqDocRef, {
        'testId': d.id,
        'name': data['name'],
        'price': data['price'],
        'container_id': data['container_id'] ?? data['containerId'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // تنفيذ الحفظ فقط إذا كان هناك تغيير فعلي
    if (removedIds.isNotEmpty || newSelectedIds.isNotEmpty) {
      await batch.commit();

      // ✅ تحديث القائمة المحلية لتتطابق مع البيانات بعد الحفظ
      _existingTestIds
        ..removeAll(removedIds)
        ..addAll(newSelectedIds);

      // إرسال إشعار (نفس الكود السابق بدون تغيير)
      if (!widget.skipNotification) {
        try {
          final pSnap = await FirebaseFirestore.instance
              .collection('labToLap')
              .doc('global')
              .collection('patients')
              .doc(widget.patientId)
              .get();

          final patientData = pSnap.data() ?? {};
          final patientName = patientData['name']?.toString() ?? 'مريض';
          final patientCode = patientData['id']?.toString() ?? widget.patientId;

          final List<String> testNames = [];
          num totalPrice = 0;
          for (final d in selectedDocs) {
            final data = d.data();
            final name = data['name']?.toString() ?? '';
            final priceDyn = data['price'];
            final priceNum = (priceDyn is num)
                ? priceDyn
                : (num.tryParse('$priceDyn') ?? 0);
            if (name.isNotEmpty) testNames.add(name);
            totalPrice += priceNum;
          }

          final labSnap = await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(widget.labId)
              .get();
          final labData = labSnap.data() ?? {};

          String whatsappNumber = labData['whatsApp']?.toString() ?? '';
          if (whatsappNumber.isEmpty) whatsappNumber = '249912345678';
          // 🟣 اجلب رقم الحساب من global/bankAccount/1
String bankAccount = '1234567';
try {
  final bankSnap = await FirebaseFirestore.instance
      .collection('labToLap')
      .doc('global')
      .collection('bankAccound')
      .doc('1')
      .get();

  final bankData = bankSnap.data();
  if (bankData != null && bankData['accound'] != null) {
    bankAccount = bankData['accound'].toString();
  }
} catch (e) {
  print('⚠️ خطأ أثناء جلب رقم الحساب: $e');
}


          final contractType = labData['contractType']?.toString() ?? 'prepaid';
          if (contractType == 'prepaid' && whatsappNumber.isNotEmpty) {
            await _sendWhatsAppMessage(
              whatsappNumber,
              patientName,
              patientCode,
              totalPrice.toStringAsFixed(0),
              bankAccount,
              widget.labName,
            );
          }

          final String lab = (widget.labName).trim();
          final String title = lab.startsWith('معمل')
              ? 'مريض جديد في $lab'
              : 'مريض جديد في معمل $lab';
          final String body =
              'اسم المريض: $patientName\nالفحوصات: ${testNames.join(', ')}\nالمبلغ: ${totalPrice.toStringAsFixed(0)}';

          await FirebaseFirestore.instance.collection('push_requests').add({
            'topic': 'lab_order',
            'title': title,
            'body': body,
            'labId': widget.labId,
            'labName': widget.labName,
            'patientDocId': widget.patientId,
            'action': 'open_order_request',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('⚠️ خطأ أثناء إرسال الإشعار: $e');
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد تغييرات لحفظها'),
          backgroundColor: Colors.orange,
        ),
      );
    }

    // الانتقال بعد الحفظ
    if (widget.skipNotification) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LabPatientResultDetailScreen(
            labId: widget.labId,
            labName: widget.labName,
            patientDocId: widget.patientId,
            fromSelection: false,
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LabPatientResultDetailScreen(
            labId: widget.labId,
            labName: widget.labName,
            patientDocId: widget.patientId,
            fromSelection: true,
          ),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فشل الحفظ: $e'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}



  Future<void> _sendWhatsAppMessage(
    String whatsappNumber,
    String patientName,
    String patientCode,
    String totalPrice,
    String bankAccount,
    String labName,
  ) async {
    try {
      final message = '''تم انشاء طلبك رقم $patientCode بنجاح ✅،
المبلغ المستحق: $totalPrice جنيه

يرجى السداد نقداً للمندوب أو عبر بنكك إلى الحساب :
 $bankAccount
مع كتابة رقم الطلب ($patientCode) في خانة التعليق عند التحويل.
شكرًا لاختيارك خدماتنا 💚
''';

      // تنظيف وتنسيق رقم الواتساب - إزالة الصفر من البداية
      String cleanNumber = whatsappNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1); // إزالة الصفر من البداية
      }
      if (cleanNumber.startsWith('249')) {
        cleanNumber = cleanNumber.substring(3);
      }
      final chatId = '249$cleanNumber@c.us';

      final uri = Uri.parse(
        'https://api.ultramsg.com/instance145504/messages/chat',
      );
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      request.bodyFields = {
        'token': 'mh3flw9ka6wm8dkw',
        'to': chatId,
        'body': message,
      };

      print('Sending WhatsApp message to: $chatId');
      print('Message: $message');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('WhatsApp API Response Status: ${response.statusCode}');
      print('WhatsApp API Response Body: $responseBody');

      if (response.statusCode == 200) {
        print('WhatsApp message sent successfully');
      } else {
        print('Failed to send WhatsApp message: ${response.statusCode}');
        print('Response: $responseBody');
      }
    } catch (e) {
      print('Error sending WhatsApp message: $e');
    }
  }

  Future<void> performSave() async {
    if (_saving) return; // يمنع الضغط المكرر
    final snap = await _priceCol.get();
    final allDocs = snap.docs;
    await _saveSelection(allDocs);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'اختيار الفحوصات',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Text(
                  _selectedIds.isEmpty ? '' : 'المحدد: ${_selectedIds.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
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
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _priceCol.snapshots(),
                        builder: (context, snap) {
                          if (snap.hasError)
                            return Center(child: Text('خطأ: ${snap.error}'));
                          if (!snap.hasData)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          final docs =
                              snap.data!.docs.where((d) {
                                final n =
                                    (d.data()['name']?.toString() ?? '')
                                        .toLowerCase();
                                if (_searchQuery.isNotEmpty &&
                                    !n.contains(_searchQuery)) {
                                  return false;
                                }

                                final price = d.data()['price'];
                                final validPrice = price is num && price > 0;

                                // إظهار الفحوصات التي hidden == false فقط
                                final hidden = d.data()['hidden'];
                                final visible = hidden == false;

                                return validPrice && visible;
                              }).toList();

                          // sort by numeric id ascending; items without valid id go last by doc id
                          docs.sort((a, b) {
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

                            final hasIdA = idA is num && idA > 0;
                            final hasIdB = idB is num && idB > 0;

                            if (hasIdA && hasIdB) return idA.compareTo(idB);
                            if (hasIdA) return -1;
                            if (hasIdB) return 1;

                            return 0;
                          });

                          return ListView.separated(
                            itemCount: docs.length,
                            padding: const EdgeInsets.all(16),
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final d = docs[i];
                              final data = d.data();
                              final name = data['name']?.toString() ?? '';
                              final price = data['price'];
                              final selected = _selectedIds.contains(d.id);
                              final isExisting = _existingTestIds.contains(
                                d.id,
                              );
                              final isUnavailable = data['available'] == false;
                              final conditions =
                                  data['condition']?.toString().trim();
                              final hasConditions =
                                  conditions != null && conditions.isNotEmpty;

                              return Card(
                                color:
                                    !isUnavailable
                                        ? (isExisting ? Colors.grey[100] : null)
                                        : Colors.grey.withOpacity(0.3),
                                child: ListTile(
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Info button for condition
                                      if (hasConditions)
                                        GestureDetector(
                                          onTap: () {
                                            _showConditionDialog(
                                              context,
                                              conditions,
                                            );
                                          },
                                          child: AnimatedBuilder(
                                            animation: _getAnimationController(
                                              d.id,
                                            ),
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale:
                                                    1.0 +
                                                    (_getAnimationController(
                                                          d.id,
                                                        ).value *
                                                        0.2),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.orange
                                                            .withOpacity(0.3),
                                                        blurRadius: 4,
                                                        spreadRadius: 1,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.info_outline,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      if (hasConditions)
                                        const SizedBox(width: 8),
                                      // Checkbox
                                      Checkbox(
                                        value: selected,
                                        onChanged:
                                            !isUnavailable
                                                ? (v) {
                                                  setState(() {
                                                    if (v == true) {
                                                      _selectedIds.add(d.id);
                                                    } else {
                                                      _selectedIds.remove(d.id);
                                                    }
                                                  });
                                                }
                                                : null,
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isExisting ? Colors.grey[600] : null,
                                    ),
                                  ),
                                  onTap:
                                      !isUnavailable
                                          ? () {
                                            setState(() {
                                              if (_selectedIds.contains(d.id)) {
                                                _selectedIds.remove(d.id);
                                              } else {
                                                _selectedIds.add(d.id);
                                              }
                                            });
                                          }
                                          : null,
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('السعر: ${price ?? 0}'),
                                      // 👇 زمن الفحص (رقم + كلمة ساعات)
                                      if (data['timer'] != null && data['timer'] is num && data['timer'] > 0)
                                        Text(
                                          'الزمن المتوقع للفحص: ${data['timer']} ساعة',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      if (isExisting)
                                        const Text(
                                          'موجود مسبقاً',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      if (isUnavailable)
                                        const Text(
                                          'غير متاح',
                                          style: TextStyle(
                                            color: Colors.red,
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
                    onPressed: _saving ? null : performSave,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF673AB7),
                      foregroundColor: Colors.white,
                    ),
                    child:
                        _saving
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
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
