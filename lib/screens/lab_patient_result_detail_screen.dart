import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
    return {
      'id': intId,
      'name': pData['name']?.toString() ?? '',
      'status': (pData['status']?.toString() ?? 'pending').toLowerCase(),
      'tests': tests,
      'pdf_url': pData['pdf_url']?.toString() ?? '',
    };
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.blue;
      case 'inprocess':
        return Colors.orange;
      case 'comlated':
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
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
  @override
  Widget build(BuildContext context) {
    return  Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text('بيانات المريض', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _loadPatientAndTests(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data ?? {'id': 0, 'name': '', 'status': 'pending', 'tests': <Map<String, dynamic>>[], 'pdf_url': ''};
            final intId = data['id'] as int? ?? 0;
            final name = data['name'] as String? ?? '';
            final status = (data['status']?.toString() ?? 'pending').toLowerCase();
            final tests = (data['tests'] as List).cast<Map<String, dynamic>>();
            final total = _calcTotal(tests);
            final pdfUrl = data['pdf_url'] as String? ?? '';

            return Column(
              children: [
                // Status chip on top-left
               /* Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _statusColor(status), width: 1),
                        ),
                        child: Text(status == 'comlated' ? 'completed' : status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),*/
                const SizedBox(height: 8),

                // Centered ID and Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(intId > 0 ? '$intId' : patientDocId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87), textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Tests list within fixed area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.separated(
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
                    ),
                  ),
                ),

                // Bottom fixed area: total, PDF button, progress bar
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
    );
  }
}
class _PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const _PdfViewerScreen({required this.pdfUrl});

  @override
  State<_PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<_PdfViewerScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _loadPdf() {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // إلغاء أي timer سابق
      _timeoutTimer?.cancel();

      // إعداد timeout لمدة 30 ثانية
      _timeoutTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'انتهت مهلة التحميل. يرجى المحاولة مرة أخرى.\n\nالرابط: ${widget.pdfUrl}';
          });
        }
      });

      print('=== بدء تحميل PDF باستخدام Google Docs Viewer ===');
      print('الرابط الأصلي: ${widget.pdfUrl}');

      // فحص صحة الرابط
      final uri = Uri.parse(widget.pdfUrl);
      if (uri.scheme.isEmpty || uri.host.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'رابط PDF غير صحيح:\n${widget.pdfUrl}';
        });
        return;
      }

      // إنشاء رابط Google Docs Viewer
      final googleDocsUrl = 'https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.pdfUrl)}';
      print('رابط Google Docs Viewer: $googleDocsUrl');

      // إنشاء WebViewController
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('بدء تحميل الصفحة: $url');
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              print('انتهاء تحميل الصفحة: $url');
              _timeoutTimer?.cancel(); // إلغاء timeout عند انتهاء التحميل
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              print('خطأ في تحميل الصفحة: ${error.description}');
              _timeoutTimer?.cancel(); // إلغاء timeout عند حدوث خطأ
              setState(() {
                _isLoading = false;
                _errorMessage = 'خطأ في تحميل PDF:\n${error.description}\n\nالرابط: ${widget.pdfUrl}';
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(googleDocsUrl));

    } catch (e) {
      print('❌ خطأ في تحميل PDF: $e');
      _timeoutTimer?.cancel(); // إلغاء timeout عند حدوث خطأ
      setState(() {
        _isLoading = false;
        _errorMessage = 'خطأ في تحميل الملف:\n$e\n\nالرابط: ${widget.pdfUrl}';
      });
    }
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
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                _loadPdf();
              },
              tooltip: 'إعادة تحميل',
            ),
          ],
        ),
        body: _buildPdfViewer(),
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _loadPdf();
                  },
                  child: const Text('إعادة المحاولة'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final Uri url = Uri.parse(widget.pdfUrl);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لا يمكن فتح الرابط'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('خطأ في فتح الرابط: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('فتح في متصفح'),
                ),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('الرابط: ${widget.pdfUrl}'),
                        duration: const Duration(seconds: 5),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('عرض الرابط'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Container(
            color: Colors.white.withOpacity(0.9),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color.fromARGB(255, 90, 138, 201),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'جاري تحميل النتيجة...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 90, 138, 201),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'يرجى الانتظار',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}