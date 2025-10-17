import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_info_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_select_tests_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class OrderRequestScreen extends StatefulWidget {
   final String labId;
  final String labName;
  final String patientDocId;
  const OrderRequestScreen({
    super.key,
    required this.labId,
    required this.labName,
    required this.patientDocId,
  });

  @override
  State<OrderRequestScreen> createState() => _OrderRequestScreenState();
}

class _OrderRequestScreenState extends State<OrderRequestScreen> {
  bool _isReceived = false;
  late Future<Map<String, dynamic>> _patientFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _patientFuture = _loadPatientAndTests();
  }

Future<Map<String, dynamic>> _loadPatientAndTests() async {
    final patientRef = FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients')
        .doc(widget.patientDocId);
    final pSnap = await patientRef.get();
    final pData = pSnap.data() ?? {};
    final idDyn = pData['id'];
    final intId = (idDyn is int) ? idDyn : int.tryParse('${idDyn ?? ''}') ?? 0;
    final testsSnap = await patientRef.collection('lab_request').get();
    final tests = testsSnap.docs.map((d) => d.data()).toList();
    
    // Format date and time
    String formattedDateTime = '';
    final createdAt = pData['createdAt'];
    if (createdAt != null) {
      try {
        DateTime dateTime;
        if (createdAt is Timestamp) {
          dateTime = createdAt.toDate();
        } else if (createdAt is DateTime) {
          dateTime = createdAt;
        } else {
          dateTime = DateTime.now();
        }
        formattedDateTime =
            '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDateTime = '';
      }
    }
    
    final result = {
      'id': intId,
      'name': pData['name']?.toString() ?? '',
      'phone': pData['phone']?.toString() ?? '',
      'status': (pData['status']?.toString() ?? 'pending').toLowerCase(),
      'tests': tests,
      'pdf_url': pData['pdf_url']?.toString() ?? '',
      'formattedDateTime': formattedDateTime,
      'order_receieved': pData['order_receieved'] == true,
      // delivered flag to control delete availability
      'sample_delivered': pData['sample_delivered'] == true,
    };
    // initialize local received flag once on first load
    _isReceived = (result['order_receieved'] as bool? ?? false);
    return result;
  }

  String _formatPrice(num price) {
    final str = price.toStringAsFixed(0);
    return str.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  num _calcTotal(List<Map<String, dynamic>> tests) {
    num total = 0;
    for (final t in tests) {
      final p = t['price'];
      if (p is num) {
        total += p;
      } else {
        final n = num.tryParse('$p');
        if (n != null) total += n;
      }
    }
    return total;
  }

  Map<String, List<Map<String, dynamic>>> _groupTestsByContainer(
    List<Map<String, dynamic>> tests,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final t in tests) {
      final String cid = _extractContainerId(t);
      if (cid.isEmpty) continue;
      grouped.putIfAbsent(cid, () => []);
      grouped[cid]!.add(t);
    }
    return grouped;
  }

  String _extractContainerId(Map<String, dynamic> t) {
    final possibleKeys = ['containerId', 'container_id', 'container', 'cid'];
    for (final key in possibleKeys) {
      final v = t[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  String? _getContainerAssetPath(String containerId) {
    if (containerId.isEmpty) return null;
    return 'assets/containars/$containerId.png';
  }

  Future<void> _deleteTest(String testId) async {
    if (testId.isEmpty) return;

    // تأكيد الحذف
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text('هل أنت متأكد من حذف هذا الفحص؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('حذف', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // البحث عن الفحص في مجموعة lab_request وحذفه
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc('global')
              .collection('patients')
              .doc(widget.patientDocId)
              .collection('lab_request')
              .where('testId', isEqualTo: testId)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف الفحص بنجاح'),
              backgroundColor: Colors.green,
            ),
          );

          // تحديث البيانات
          setState(() {
            _patientFuture = _loadPatientAndTests();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الفحص: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // تمت إزالة التعديل حسب الطلب؛ يُسمح فقط بالحذف قبل التوصيل
  
  // Back handled via Navigator.pop directly in UI; no helper needed.
  Future<void> _cancelOrder(
    BuildContext context,
    String patientDocId,
    String labId,
  ) async {
    // تأكيد الإلغاء
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الإلغاء'),
            content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'تأكيد الإلغاء',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // جلب اسم المستخدم من SharedPreferences
      String cancelledByName = 'المشرف';
      try {
        final prefs = await SharedPreferences.getInstance();
        final userName = prefs.getString('userName');
        if (userName != null && userName.trim().isNotEmpty) {
          cancelledByName = userName.trim();
        }
      } catch (_) {}

      // تحديث حالة الطلب إلى ملغي
      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(patientDocId)
          .update({
            'status': 'cancelled',
            'cancelled_at': FieldValue.serverTimestamp(),
            'cancelled_by': cancelledByName,
          });

      // جلب بيانات المريض لإرسال الرسالة
      final pSnap =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc('global')
              .collection('patients')
              .doc(patientDocId)
              .get();
      final pData = pSnap.data() ?? {};
      final patientName = pData['name']?.toString() ?? 'غير معروف';
      final patientPhone = pData['phone']?.toString() ?? '';

      // جلب رقم الهاتف العادي للمعمل
      final labDoc =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(labId)
              .get();
      final labPhone = labDoc.data()?['phone']?.toString() ?? '';

      // إرسال رسالة نصية للمعمل
      if (labPhone.isNotEmpty) {
        await _sendCancellationSms(labPhone, patientName, patientPhone);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // العودة للصفحة السابقة
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إلغاء الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendCancellationSms(
    String labPhone,
    String patientName,
    String patientPhone,
  ) async {
    try {
      final String formattedPhone = _formatSudanPhone(labPhone);
      const String baseUrl = 'https://api.airtel.com.sd/api/send-sms';
      const String username = 'jawda';
      const String password = 'jawda123';
      const String sender = 'Jawda';

      final String message =
          'تم إلغاء طلب المريض\nاسم المريض: $patientName\nرقم الهاتف: $patientPhone';
      final String encodedText = Uri.encodeComponent(message);
      final String encodedSender = Uri.encodeComponent(sender);
      final String url =
          '${baseUrl}?username=${username}&password=${Uri.encodeComponent(password)}&phone_number=${formattedPhone}&message=${encodedText}&sender=${encodedSender}';

      final response = await http.get(Uri.parse(url));
      print('SMS Response: ${response.statusCode} ${response.body}');
    } catch (e) {
      print('SMS Error: $e');
    }
  }

  String _formatSudanPhone(String phone) {
    phone = phone.trim();
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    if (!phone.startsWith('249')) {
      phone = '249$phone';
    }
    return phone;
  }

  Future<void> _receiveOrder(
    BuildContext context,
    String patientDocId,
    String labId,
  ) async {
    setState(() => _isLoading = true);
    try {
      // Read controller name from local storage
      String acceptedByName = 'المشرف';
      try {
        final prefs = await SharedPreferences.getInstance();
        final n = prefs.getString('userName');
        if (n != null && n.trim().isNotEmpty) {
          acceptedByName = n.trim();
        }
      } catch (_) {}

      // 1) Mark order as received
      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(patientDocId)
          .update({
            'order_receieved': true,
            'order_receieved_by_name': acceptedByName,
            'order_receieved_at': FieldValue.serverTimestamp(),
          });

      // 2) Load patient to get name & phone
      final pSnap =
          await FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(patientDocId)
          .get();
      final pData = pSnap.data() ?? {};
      final patientName = pData['name']?.toString() ?? 'غير معروف';
      final patientPhone = pData['phone']?.toString() ?? '';
     
      final topic = labId;
      const title = 'تم استلام طلبك';
      final body =
          patientPhone.isNotEmpty
          ? 'اسم المريض: ' + patientName + '\nرقم الهاتف: ' + patientPhone
          : 'اسم المريض: ' + patientName;

      await FirebaseFirestore.instance.collection('push_requests').add({
        'topic': topic,
        'title': title,
        'body': body,
        'labId': widget.labId,
        'labName': widget.labName,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        setState(() {
          _isReceived = true;
        });
      }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في استلام الطلب: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
// فتح جوجل مابس بالإحداثيات
Future<void> _openInGoogleMaps(double lat, double lng) async {
  final Uri googleMapUrl = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
  );

  if (await canLaunchUrl(googleMapUrl)) {
    await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication);
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن فتح تطبيق الخرائط'),
          backgroundColor: Colors.red,
        ),
    );
  }
}

Future<Map<String, double>?> _fetchLabLocation() async {
  try {
      final docSnap =
          await FirebaseFirestore.instance
        .collection('labToLap')
        .doc(widget.labId)
        .get();

    if (!docSnap.exists) return null;

    final data = docSnap.data();
    if (data == null) return null;

    final location = data['location'];
    if (location == null) return null;

    if (location is GeoPoint) {
      return {'lat': location.latitude, 'lng': location.longitude};
    }
    final lat = location['lat'];
    final lng = location['lng'];
    if (lat is double && lng is double) {
      return {'lat': lat, 'lng': lng};
    } else if (lat is num && lng is num) {
      return {'lat': lat.toDouble(), 'lng': lng.toDouble()};
    }

    return null;
  } catch (e) {
    print('Error fetching lab location: $e');
    return null;
  }
}

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: WillPopScope(
        onWillPop: () async {
          // Allow system back to pop to the exact previous screen
          return true;
        },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.labName.contains('معمل')
                  ? widget.labName
                  : 'مختبر ${widget.labName}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
            backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => LabSelectTestsScreen(
                            labId: widget.labId,
                            labName: widget.labName,
                            patientId: widget.patientDocId,
                            skipNotification:
                                true, // تخطي الإشعار عند الإضافة من صفحة الطلب
                          ),
                    ),
                  ).then((_) {
                    // تحديث البيانات عند العودة من صفحة إضافة الفحوصات
                    setState(() {
                      _patientFuture = _loadPatientAndTests();
                    });
                  });
                },
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: 'إضافة فحص جديد',
              ),
            ],
        ),
        
        body: Container(
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
          child: FutureBuilder<Map<String, dynamic>>(
          future: _patientFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
                final data =
                    snap.data ??
                    {
                      'id': 0,
                      'name': '',
                      'phone': '',
                      'status': 'pending',
                      'tests': <Map<String, dynamic>>[],
                      'pdf_url': '',
                      'formattedDateTime': '',
                    };
            final intId = data['id'] as int? ?? 0;
            final name = data['name'] as String? ?? '';
            final phone = data['phone'] as String? ?? '';
                final tests =
                    (data['tests'] as List).cast<Map<String, dynamic>>();
            final total = _calcTotal(tests);
            final pdfUrl = data['pdf_url'] as String? ?? '';
                final formattedDateTime =
                    data['formattedDateTime'] as String? ?? '';
                final receivedFromData =
                    (data['order_receieved'] as bool? ?? false);
            final bool isReceived = _isReceived || receivedFromData;
                final String status = data['status']?.toString() ?? 'pending';
                final bool isCancelled = status == 'cancelled';
                final bool isDelivered =
                    (data['sample_delivered'] as bool? ?? false);

            return Column(
              children: [
                const SizedBox(height: 8),

// Patient info card with icons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFF673AB7),
                            width: 1.5,
                          ),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                          // Code on the left with larger font
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الكود',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                      intId > 0
                                          ? '$intId'
                                          : widget.patientDocId,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                        color: Color(0xFF673AB7),
                                  ),
                      ),
                    ],
                  ),
                ),
                          // Name and phone on the right
                          Expanded(
                            flex: 2,
                    child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                                // Date and time above name
                                if (formattedDateTime.isNotEmpty) ...[
                                  Text(
                                    formattedDateTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                // Patient name
                               Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12.0,
                                      ), // ← زيادة المسافة للاسم الرباعي
  child: Align(
    alignment: Alignment.centerRight,
    child: Text(
                                  name,
      textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
      ),
    ),
                                  ),
                                ),
                                // Phone as subtitle
                                if (phone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    phone,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

// Tests + containers list within fixed area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Builder(
                      builder: (context) {
                        final grouped = _groupTestsByContainer(tests);
                        final entries = grouped.entries.toList();
                        if (entries.isEmpty) {
                          // Fallback: show flat tests list if no containers
                              if (tests.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 16),
                                      const Text(
                                        'لا توجد فحوصات مضافة',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (
                                                    context,
                                                  ) => LabSelectTestsScreen(
                                                    labId: widget.labId,
                                                    labName: widget.labName,
                                                    patientId:
                                                        widget.patientDocId,
                                                    skipNotification:
                                                        true, // تخطي الإشعار عند الإضافة من صفحة الطلب
                                                  ),
                                            ),
                                          ).then((_) {
                                            setState(() {
                                              _patientFuture =
                                                  _loadPatientAndTests();
                                            });
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                        label: const Text('إضافة فحوصات'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF673AB7,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                          return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tests.length,
                                separatorBuilder:
                                    (_, __) => const Divider(height: 8),
                      itemBuilder: (context, i) {
                        final t = tests[i];
                        final tName = t['name']?.toString() ?? '';
                        final priceDyn = t['price'];
                                  final price =
                                      (priceDyn is num)
                                          ? priceDyn
                                          : (num.tryParse('$priceDyn') ?? 0);
                                  final testId = t['testId']?.toString() ?? '';

                        return Row(
                          children: [
                                      Expanded(
                                        child: Text(
                                          '${i + 1}- $tName',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatPrice(price),
                                        style: const TextStyle(
                                          color: Colors.black87,
                                        ),
                                      ),
                                      // حذف فقط قبل توصيل العينة (flat list)
                                      if (!isDelivered)
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert,
                                            size: 16,
                                          ),
                                          onSelected: (value) async {
                                            if (value == 'delete') {
                                              await _deleteTest(testId);
                                            }
                                          },
                                          itemBuilder:
                                              (context) => [
                                                const PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                        size: 16,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'حذف',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                        ),
                          ],
                              );
                            },
                          );
                        }
                            if (tests.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.science,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'لا توجد فحوصات مضافة',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'اضغط على زر + لإضافة فحوصات جديدة',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (
                                                  context,
                                                ) => LabSelectTestsScreen(
                                                  labId: widget.labId,
                                                  labName: widget.labName,
                                                  patientId:
                                                      widget.patientDocId,
                                                  skipNotification:
                                                      true, // تخطي الإشعار عند الإضافة من صفحة الطلب
                                                ),
                                          ),
                                        ).then((_) {
                                          setState(() {
                                            _patientFuture =
                                                _loadPatientAndTests();
                                          });
                                        });
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة فحوصات'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF673AB7,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFF673AB7),
                                  width: 1.2,
                                ),
                          ),
                          child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 400,
                                ),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                      children:
                                          entries.asMap().entries.map((
                                            entryWithIndex,
                                          ) {
                                    final i = entryWithIndex.key;
                                    final entry = entryWithIndex.value;
                                    final cid = entry.key;
                                            final testsForContainer =
                                                entry.value;
                                            final assetPath =
                                                _getContainerAssetPath(cid);
                                            final isLast =
                                                i == entries.length - 1;
                                    
                                    return Column(
                                      children: [
                                         Row(
                                                  crossAxisAlignment:
                                                      testsForContainer
                                                                  .length <=
                                                              2
                                                          ? CrossAxisAlignment
                                                              .center
                                                          : CrossAxisAlignment
                                                              .start,
                                          children: [
                                            SizedBox(
                                              width: 72,
                                              height: 72,
                                                      child:
                                                          assetPath == null
                                                              ? const Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .image_not_supported,
                                                                  color:
                                                                      Colors
                                                                          .grey,
                                                                ),
                                                              )
                                                  : Image.asset(
                                                      assetPath,
                                                                fit:
                                                                    BoxFit
                                                                        .contain,
                                                                errorBuilder:
                                                                    (
                                                                      context,
                                                                      error,
                                                                      stack,
                                                                    ) => const Center(
                                                                      child: Icon(
                                                                        Icons
                                                                            .image_not_supported,
                                                                        color:
                                                                            Colors.grey,
                                                                      ),
                                                                    ),
                                                              ),
                                                    ),

const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                children: [
                                                          ...testsForContainer.map((
                                                            t,
                                                          ) {
                                                            final tName =
                                                                t['name']
                                                                    ?.toString() ??
                                                                '';
                                                            final priceDyn =
                                                                t['price'];
                                                            final price =
                                                                (priceDyn
                                                                        is num)
                                                                    ? priceDyn
                                                                    : (num.tryParse(
                                                                          '$priceDyn',
                                                                        ) ??
                                                                        0);
                                                            final testId =
                                                                t['testId']
                                                                    ?.toString() ??
                                                                '';

                                                    return Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    bottom: 4,
                                                                  ),
                                                      child: Row(
                                                        children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      '- $tName',
                                                                      style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    _formatPrice(
                                                                      price,
                                                                    ),
                                                                    style: const TextStyle(
                                                                      color:
                                                                          Colors
                                                                              .black87,
                                                                    ),
                                                                  ),
                                                                  // حذف فقط قبل توصيل العينة (grouped list)
                                                                  if (!isDelivered)
                                                                    PopupMenuButton<
                                                                      String
                                                                    >(
                                                                      icon: const Icon(
                                                                        Icons
                                                                            .more_vert,
                                                                        size:
                                                                            16,
                                                                      ),
                                                                      onSelected: (
                                                                        value,
                                                                      ) async {
                                                                        if (value ==
                                                                            'delete') {
                                                                          await _deleteTest(
                                                                            testId,
                                                                          );
                                                                        }
                                                                      },
                                                                      itemBuilder:
                                                                          (
                                                                            context,
                                                                          ) => [
                                                                            const PopupMenuItem<
                                                                              String
                                                                            >(
                                                                              value:
                                                                                  'delete',
                                                                              child: Row(
                                                                                children: [
                                                                                  Icon(
                                                                                    Icons.delete,
                                                                                    color:
                                                                                        Colors.red,
                                                                                    size:
                                                                                        16,
                                                                                  ),
                                                                                  SizedBox(
                                                                                    width:
                                                                                        8,
                                                                                  ),
                                                                                  Text(
                                                                                    'حذف',
                                                                                    style: TextStyle(
                                                                                      color:
                                                                                          Colors.red,
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                    ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (!isLast) ...[
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 12),
                                        ],
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

// Bottom fixed area: total, Containers button (stacked), PDF button
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.center,
                              child: Text(
                                'المبلغ: ${_formatPrice(total)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                        ),
                        const SizedBox(height: 8),
                       
                        // Two buttons in a row: Lab Info and View Result
                        Row(
                          children: [
                            // Lab Info Button
                            Expanded(
                              child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'بيانات المعمل',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF673AB7),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                          builder:
                                              (context) => LabInfoScreen(
                                        labId: widget.labId, 
                                        labName: widget.labName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // View Result Button
                            Expanded(
                              child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'عرض النتيجة',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          pdfUrl.isNotEmpty
                                              ? const Color(0xFF673AB7)
                                      : Colors.grey[400]!,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                    onPressed:
                                        pdfUrl.isNotEmpty
                                            ? () {
                                  // Navigate to PDF viewer screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          _PdfViewerScreen(
                                        pdfUrl: pdfUrl,
                                        data: data,
                                        labId: widget.labId,
                                      ),
                                    ),
                                  );
                                            }
                                            : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                       
                            // زرين في صف واحد: استلام الطلب وإلغاء الطلب
                            Row(
                              children: [
                                // زر استلام الطلب
                                Expanded(
                                  child:
                                      isReceived
      ? ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                            ),
                                            label: const Text(
                                              'الموقع',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
          style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF673AB7,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
            ),
          ),
          onPressed: () async {
                                              final location =
                                                  await _fetchLabLocation();
            if (location != null) {
                                                await _openInGoogleMaps(
                                                  location['lat']!,
                                                  location['lng']!,
                                                );
            } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                const SnackBar(
                                                    content: Text(
                                                      'لم يتم العثور على إحداثيات المختبر',
                                                    ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        )
      : ElevatedButton(
                                            onPressed:
                                                _isLoading || isCancelled
                                                    ? null
                                                    : () {
                                                      _receiveOrder(
                                                        context,
                                                        widget.patientDocId,
                                                        widget.labId,
                                                      );
          },
                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  isCancelled
                                                      ? Colors.grey
                                                      : const Color(0xFF673AB7),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child:
                                                _isLoading
                                                    ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2.5,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(Colors.white),
                                                      ),
                                                    )
                                                    : Text(
                                                      isCancelled
                                                          ? 'استلام الطلب'
                                                          : 'استلام الطلب',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                          ),
                                ),
                                const SizedBox(width: 8),
                                // زر إلغاء الطلب
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading || isCancelled
                                            ? null
                                            : () {
                                              _cancelOrder(
                                                context,
                                                widget.patientDocId,
                                                widget.labId,
                                              );
                                            },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isCancelled
                                              ? Colors.grey
                                              : const Color.fromARGB(255, 143, 99, 219),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child:
                                        _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : Text(
                                              isCancelled
                                                  ? 'تم الإلغاء'
                                                  : 'إلغاء الطلب',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ),
        ),
      ),
    );
  }
}

class _PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final Map<String, dynamic> data;
  final String labId;

  const _PdfViewerScreen({
    required this.pdfUrl,
    required this.data,
    required this.labId,
  });

  Future<void> _sendToWhatsapp(
    String toChatId,
    String pdfUrl,
    BuildContext context,
  ) async {
    try {
      // Send the PDF file itself using UltraMsg document API
      final uri = Uri.parse(
        'https://api.ultramsg.com/instance140877/messages/document',
      );
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
      request.bodyFields = {
        'token': 'df2r46jz82otkegg',
        'to': toChatId, // e.g. 249XXXXXXXXX@c.us
        'document': pdfUrl, // direct URL to the PDF
        'filename': 'lab_result.pdf',
        'caption': 'نتيجة التحليل PDF',
      };

      final response = await request.send();
      if (response.statusCode == 200) {
        await response.stream.bytesToString();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إرسال النتيجة عبر واتساب')), 
          );
          // إظهار رسالة تأكيد واضحة للمستخدم
          await showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
              title: const Text('تم الإرسال'),
              content: const Text('تم إرسال النتيجة بنجاح عبر واتساب.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل الإرسال (${response.reasonPhrase})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الإرسال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  String _formatPhoneNumber(String input) {
    input = input.trim();
    if (input.startsWith('0')) {
      input = input.substring(1);
    }
    if (!input.startsWith('249')) {
      input = '249$input';
    }
    return input;
  }

  void _showWhatsappDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String labId,
  ) {
    final TextEditingController _phoneController = TextEditingController();
    String selectedRecipient = 'patient'; // default value
    bool isLoading = false;

    Future<void> _fillPhoneField() async {
      if (selectedRecipient == 'lab') {
        try {
          final doc =
              await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(labId)
              .get();
          final labPhone = doc.data()?['whatsApp']?.toString() ?? '';
          _phoneController.text = labPhone;
        } catch (e) {
          _phoneController.text = '';
        }
      } else {
        final patientPhone = data['phone']?.toString() ?? '';
        _phoneController.text = patientPhone;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        _fillPhoneField();

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("إرسال النتيجة عبر واتساب"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Radio<String>(
                        value: 'patient',
                        groupValue: selectedRecipient,
                        onChanged: (value) {
                          setState(() {
                            selectedRecipient = value!;
                            _fillPhoneField();
                          });
                        },
                      ),
                      const Text("للمريض"),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'lab',
                        groupValue: selectedRecipient,
                        onChanged: (value) {
                          setState(() {
                            selectedRecipient = value!;
                            _fillPhoneField();
                          });
                        },
                      ),
                      const Text("لنفسي"),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: "أدخل رقم واتساب",
                      labelText: "رقم الهاتف",
                      labelStyle: const TextStyle(color: Colors.black),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF673AB7)),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(color: Colors.black),
                  ),
                  onPressed: () {
                    if (!isLoading) Navigator.pop(context);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                  ),
                  onPressed:
                      isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                          });

                          String rawInput = _phoneController.text;
                            String formattedPhone = _formatPhoneNumber(
                              rawInput,
                            );

                          final pdfUrl = data['pdf_url']?.toString() ?? '';

                          if (pdfUrl.isNotEmpty) {
                              await _sendToWhatsapp(
                                '$formattedPhone@c.us',
                                pdfUrl,
                                context,
                              );
                            if (context.mounted) Navigator.pop(context);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('لا يوجد رابط PDF'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }

                          if (context.mounted) {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        },
                  child:
                      isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                          : const Text(
                            "إرسال النتيجة",
                            style: TextStyle(color: Colors.white),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'عرض النتيجة PDF',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(
                FontAwesomeIcons.whatsapp,
                color: Color.fromARGB(255, 2, 48, 4),
              ),
              tooltip: 'إرسال عبر واتساب',
              onPressed: () {
                _showWhatsappDialog(context, data, labId);
              },
            ),
          ],
        ),
        
        body: SfPdfViewer.network(
          pdfUrl,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          enableDoubleTapZooming: true,
        ),
      ),
    );
  }
}
