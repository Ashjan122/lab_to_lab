import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:http/http.dart' as http;
// removed containers_screen import; containers shown inline


class LabPatientResultDetailScreen extends StatelessWidget {
   final String labId;
  final String labName;
  final String patientDocId;
  const LabPatientResultDetailScreen({super.key, required this.labId, required this.labName, required this.patientDocId});
 Future<Map<String, dynamic>> _loadPatientAndTests() async {
    final patientRef = FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients')
        .doc(patientDocId);
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
        formattedDateTime = '${dateTime.day}/${dateTime.month}/${dateTime.year} - ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedDateTime = '';
      }
    }
    
    return {
      'id': intId,
      'name': pData['name']?.toString() ?? '',
      'phone': pData['phone']?.toString() ?? '',
      'status': (pData['status']?.toString() ?? 'pending').toLowerCase(),
      'tests': tests,
      'pdf_url': pData['pdf_url']?.toString() ?? '',
      'formattedDateTime': formattedDateTime,
    };
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

  Map<String, List<Map<String, dynamic>>> _groupTestsByContainer(List<Map<String, dynamic>> tests) {
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

  void _openPdf(BuildContext context, String pdfUrl) {
    if (pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رابط PDF غير صحيح'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PdfViewerScreen(pdfUrl: pdfUrl),
      ),
    );
  }
  // Back handled via Navigator.pop directly in UI; no helper needed.

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
          title: const Text('بيانات المريض', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey.shade200,
                const Color.fromARGB(255, 90, 138, 201).withOpacity(0.2),
                const Color.fromARGB(255, 90, 138, 201).withOpacity(0.35),
              ],
            ),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
          future: _loadPatientAndTests(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data ?? {'id': 0, 'name': '', 'phone': '', 'status': 'pending', 'tests': <Map<String, dynamic>>[], 'pdf_url': '', 'formattedDateTime': ''};
            final intId = data['id'] as int? ?? 0;
            final name = data['name'] as String? ?? '';
            final phone = data['phone'] as String? ?? '';
            final tests = (data['tests'] as List).cast<Map<String, dynamic>>();
            final total = _calcTotal(tests);
            final pdfUrl = data['pdf_url'] as String? ?? '';
            final formattedDateTime = data['formattedDateTime'] as String? ?? '';

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
                      side: const BorderSide(color: Color.fromARGB(255, 90, 138, 201), width: 1.5),
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
                                  intId > 0 ? '$intId' : patientDocId,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 90, 138, 201),
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
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
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
                          return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tests.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, i) {
                        final t = tests[i];
                        final tName = t['name']?.toString() ?? '';
                        final priceDyn = t['price'];
                        final price = (priceDyn is num) ? priceDyn : (num.tryParse('$priceDyn') ?? 0);
                        return Row(
                          children: [
                            Expanded(child: Text('${i + 1}- $tName', style: const TextStyle(fontWeight: FontWeight.bold))),
                            Text(_formatPrice(price), style: const TextStyle(color: Colors.black87)),
                          ],
                              );
                            },
                          );
                        }
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color.fromARGB(255, 90, 138, 201), width: 1.2),
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 400),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: entries.asMap().entries.map((entryWithIndex) {
                                    final i = entryWithIndex.key;
                                    final entry = entryWithIndex.value;
                                    final cid = entry.key;
                                    final testsForContainer = entry.value;
                                    final assetPath = _getContainerAssetPath(cid);
                                    final isLast = i == entries.length - 1;
                                    
                                    return Column(
                                      children: [
                                         Row(
                                           crossAxisAlignment: testsForContainer.length <= 2 ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 72,
                                              height: 72,
                                              child: assetPath == null
                                                  ? const Center(child: Icon(Icons.image_not_supported, color: Colors.grey))
                                                  : Image.asset(
                                                      assetPath,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                                                    ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ...testsForContainer.map((t) {
                                                    final tName = t['name']?.toString() ?? '';
                                                    final priceDyn = t['price'];
                                                    final price = (priceDyn is num) ? priceDyn : (num.tryParse('$priceDyn') ?? 0);
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 4),
                                                      child: Row(
                                                        children: [
                                                          Expanded(child: Text('- $tName', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                          Text(_formatPrice(price), style: const TextStyle(color: Colors.black87)),
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
                          child: Text('المبلغ: ${_formatPrice(total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: pdfUrl.isNotEmpty ? () {
                              _openPdf(context, pdfUrl);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: pdfUrl.isNotEmpty ? Colors.white : Colors.grey[300],
                              foregroundColor: pdfUrl.isNotEmpty ? Colors.black : Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: pdfUrl.isNotEmpty ? const Color.fromARGB(255, 90, 138, 201) : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              pdfUrl.isNotEmpty ? 'عرض النتيجة PDF' : 'لا يوجد نتيجة حاليا',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Segmented progress bar (4 segments) LTR: pending starts at left
                        /*Builder(
                          builder: (context) {
                            final labels = ['pending', 'received', 'inprocess', 'completed'];
                            final colors = [Colors.grey, Colors.blue, Colors.orange, Colors.green];
                            int activeIndex = 0;
                            switch (status) {
                              case 'received':
                                activeIndex = 1;
                                break;
                              case 'inprocess':
                                activeIndex = 2;
                                break;
                              case 'comlated':
                              case 'completed':
                                activeIndex = 3;
                                break;
                              case 'pending':
                              default:
                                activeIndex = 0;
                            }
                            return Column(
                              children: [
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 14,
                                      child: Row(
                                        children: List.generate(4, (i) {
                                          final bool isActive = i == activeIndex;
                                          return Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isActive ? colors[i] : colors[i].withOpacity(0.25),
                                                border: isActive ? Border.all(color: colors[i], width: 2) : null,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Status labels under the bar with active emphasis
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: List.generate(4, (i) {
                                      final bool isActive = i == activeIndex;
                                      return Text(
                                        labels[i],
                                        style: TextStyle(
                                          color: colors[i],
                                          fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                                          fontSize: 12,
                                          decoration: isActive ? TextDecoration.underline : TextDecoration.none,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),*/
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

  const _PdfViewerScreen({required this.pdfUrl});
  Future<void> _sendToWhatsapp(String toChatId, String pdfUrl, BuildContext context) async {
    try {
      // Send the PDF file itself using UltraMsg document API
      final uri = Uri.parse('https://api.ultramsg.com/instance140877/messages/document');
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
            builder: (ctx) => AlertDialog(
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
            SnackBar(content: Text('فشل الإرسال (${response.reasonPhrase})'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الإرسال: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  void _showWhatsappDialog(BuildContext context) {
  final TextEditingController _phoneController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("إرسال النتيجة عبر واتساب"),
        content: TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: "أدخل رقم واتساب",
            labelText: "رقم الهاتف",
            labelStyle: const TextStyle(color: Colors.black),
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Color.fromARGB(255, 90, 138, 201)),
            ),
          ),
        ),
        actions: [
          // 🔲 زر إلغاء (أسود)
          TextButton(
            child: const Text(
              "إلغاء",
              style: TextStyle(color: Colors.black),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),

          // 🟦 زر إرسال النتيجة (بلون مخصص)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 90, 138, 201),
            ),
            child: const Text("إرسال النتيجة", style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              String input = _phoneController.text.trim();

              // ✅ حذف أول صفر إذا وُجد
              if (input.startsWith('0')) {
                input = input.substring(1);
              }

              // ✅ إضافة مفتاح السودان داخليًا فقط
              String phone = '249$input';

              // ✅ إرسال إلى واتساب باستخدام chat ID
              _sendToWhatsapp('$phone@c.us', pdfUrl, context);
            },
          ),
        ],
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
          title: const Text('عرض النتيجة PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(FontAwesomeIcons.whatsapp, color: Color.fromARGB(255, 2, 48, 4)),
              tooltip: 'إرسال عبر واتساب',
              onPressed: () {
                _showWhatsappDialog(context);
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