import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LabPatientInfoScreen extends StatelessWidget {
  final String labId;
  final String labName;
  final String patientDocId;

  const LabPatientInfoScreen({
    super.key,
    required this.labId,
    required this.labName,
    required this.patientDocId,
  });
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      // Handle error - phone app not available
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'معلومات المريض',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('labToLap')
                  .doc('global')
                  .collection('patients')
                  .doc(patientDocId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Center(child: Text('لا توجد بيانات للمريض'));
            }

            final data = snapshot.data!.data()!;
            final name = data['name']?.toString() ?? 'غير محدد';
            final phone = data['phone']?.toString() ?? 'غير محدد';
            final patientId = data['id']?.toString() ?? patientDocId;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(label: 'الاسم', value: name),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            label: 'رقم الهاتف',
                            value: phone,
                            isPhone: true,
                            onTap: () => _makePhoneCall(phone),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(label: 'كود المريض', value: patientId),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isPhone = false,
    VoidCallback? onTap,
  }) {
    return Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onTap,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isPhone && onTap != null
                            ? const Color(0xFF673AB7)
                            : Colors.black87,
                    decoration:
                        isPhone && onTap != null
                            ? TextDecoration.underline
                            : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
