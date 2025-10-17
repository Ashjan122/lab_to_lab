import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/claim_screen.dart';

class ClaimLabsPickerScreen extends StatelessWidget {
  const ClaimLabsPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('labToLap');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختيار معمل للمطالبة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: col.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('لا توجد معامل'));
            // sort by name
            docs.sort((a, b) => (a.data()['name']?.toString() ?? '').compareTo(b.data()['name']?.toString() ?? ''));

            return ListView.separated(
              itemCount: docs.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final d = docs[i];
                final data = d.data();
                final name = data['name']?.toString() ?? '';
                final address = data['address']?.toString() ?? '';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.science, color: Color(0xFF673AB7)),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: address.isEmpty ? null : Text(address),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ClaimScreen(labId: d.id, labName: name)),
                      );
                    },
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


