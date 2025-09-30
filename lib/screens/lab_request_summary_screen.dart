import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_results_patients_screen.dart';

class LabRequestSummaryScreen extends StatelessWidget {
  final String labId;
  final String labName;
  final String patientId;
  final List<Map<String, dynamic>>? selectedTests; // {name, price, containerId} - optional for existing requests
  final bool fromPatientsList;
  const LabRequestSummaryScreen({super.key, required this.labId, required this.labName, required this.patientId, this.selectedTests, this.fromPatientsList = false});

Future<Map<String, dynamic>> _getPatientInfo() async {
    final doc = await FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients')
        .doc(patientId)
        .get();
    final data = doc.data() ?? {};
    final dynamicId = data['id'];
    final intId = (dynamicId is int) ? dynamicId : int.tryParse('${dynamicId ?? ''}') ?? 0;
    return {
      'id': intId,
      'name': data['name']?.toString() ?? '',
    };
  }

  Future<List<Map<String, dynamic>>> _getAllTests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('labToLap')
        .doc('global')
        .collection('patients')
        .doc(patientId)
        .collection('lab_request')
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['name']?.toString() ?? '',
        'price': data['price'],
        'containerId': data['container_id'] ?? data['containerId'],
      };
    }).toList();
  }

  String? _getContainerAssetPath(String containerId) {
    if (containerId.isEmpty) return null;
    return 'assets/containars/$containerId.png';
  }

  num _totalPrice(List<Map<String, dynamic>> tests) {
    num sum = 0;
    for (final t in tests) {
      final p = t['price'];
      if (p is num) sum += p; else { final n = num.tryParse('$p'); if (n != null) sum += n; }
    }
    return sum;
  }

  String _formatPrice(num price) {
    final str = price.toStringAsFixed(0);
    return str.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ملخص الطلب ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _getPatientInfo(),
          builder: (context, patientSnapshot) {
            if (patientSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final info = patientSnapshot.data ?? {'id': 0, 'name': ''};
            final patientIdNum = info['id'] as int? ?? 0;
            final patientName = info['name'] as String? ?? '';
            
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _getAllTests(),
              builder: (context, testsSnapshot) {
                if (testsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allTests = testsSnapshot.data ?? [];
                final totalPrice = _totalPrice(allTests);
                
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    patientIdNum > 0 ? '$patientIdNum' : '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25, color: Colors.black87),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    patientName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final Map<String, List<String>> containerToNames = {};
                                for (final t in allTests) {
                                  final containerId = (t['containerId'] ?? t['container_id'])?.toString() ?? '';
                                  final name = t['name']?.toString() ?? '';
                                  if (containerId.isEmpty && name.isEmpty) continue;
                                  containerToNames.putIfAbsent(containerId, () => []);
                                  if (name.isNotEmpty) containerToNames[containerId]!.add(name);
                                }
                                final entries = containerToNames.entries.toList();
                                return SizedBox(
                                  height: 360,
                                  child: ListView.separated(
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: entries.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final e = entries[index];
                                      final cid = e.key;
                                      final names = e.value;
                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 64,
                                                height: 64,
                                                child: Builder(
                                                  builder: (context) {
                                                    final assetPath = _getContainerAssetPath(cid);
                                                    if (assetPath == null) {
                                                      return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 28));
                                                    }
                                                    return Image.asset(
                                                      assetPath,
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return const Center(child: Icon(Icons.image_not_supported, color: Colors.grey, size: 28));
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  names.join(' , '),
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Update bottom navigation bar with new total
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
                                'المبلغ: ${_formatPrice(totalPrice)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: fromPatientsList
                                    ? null
                                    : () {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => LabResultsPatientsScreen(labId: labId, labName: labName),
                                          ),
                                          (route) => false, // Remove all previous routes
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: Color.fromARGB(255, 90, 138, 201), width: 2),
                                  ),
                                ),
                                child: Text(fromPatientsList ? 'عرض النتيجة' : 'متابعة', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}