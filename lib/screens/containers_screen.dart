import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ContainersScreen extends StatelessWidget {
  final String labId;
  final String labName;
  final String patientDocId;

  const ContainersScreen({
    super.key,
    required this.labId,
    required this.labName,
    required this.patientDocId,
  });

  Future<List<Map<String, dynamic>>> _getAllTests() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('labToLap')
            .doc('global')
            .collection('patients')
            .doc(patientDocId)
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'أنابيب الفحوصات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _getAllTests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allTests = snapshot.data ?? [];
            if (allTests.isEmpty) {
              return const Center(child: Text('لا توجد فحوصات'));
            }

            // Group tests by container
            final Map<String, List<String>> containerToNames = {};
            for (final t in allTests) {
              final containerId =
                  (t['containerId'] ?? t['container_id'])?.toString() ?? '';
              final name = t['name']?.toString() ?? '';
              if (containerId.isEmpty && name.isEmpty) continue;
              containerToNames.putIfAbsent(containerId, () => []);
              if (name.isNotEmpty) containerToNames[containerId]!.add(name);
            }
            final entries = containerToNames.entries.toList();

            return ListView.separated(
              itemCount: entries.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final entry = entries[i];
                final cid = entry.key;
                final names = entry.value;

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Builder(
                            builder: (context) {
                              final assetPath = _getContainerAssetPath(cid);
                              if (assetPath == null) {
                                return const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 32,
                                  ),
                                );
                              }
                              return Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                      size: 32,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...names.map(
                                (name) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $name',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}
