import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/lab_new_sample_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_results_patients_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_select_tests_screen.dart';

class SuccessRequestScreen extends StatelessWidget {
  final String labId;
  final String labName;
  final String patientDocId;
  const SuccessRequestScreen({super.key, required this.labId, required this.labName, required this.patientDocId});

  Future<void> _cancelOrder(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('userName') ?? 'الكنترول';
      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(patientDocId)
          .set({
        'status': 'cancelled',
        'cancelled_by': userName,
        'cancelled_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LabResultsPatientsScreen(labId: labId, labName: labName),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إلغاء الطلب: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditOptionsDialog(BuildContext context, String name, String phone, String barcode) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'اختر نوع التعديل',
            style: TextStyle(
              
              color: Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ما الذي تريد تعديله؟',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              // زر تعديل البيانات الأساسية
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LabNewSampleScreen(
                          labId: labId,
                          labName: labName,
                          existingPatientId: patientDocId,
                          existingName: name,
                          existingPhone: phone,
                          existingBarcode: barcode,
                          isEditMode: true,
                        ),
                      ),
                    );
                  },
                  
                  label: const Text(
                    'تعديل البيانات الأساسية',
                    style: TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  Colors.white,
                    
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Color(0xFF673AB7), width: 2 )
                      
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // زر تعديل الفحوصات
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LabSelectTestsScreen(
                          labId: labId,
                          labName: labName,
                          patientId: patientDocId,
                          skipNotification: true,
                        ),
                      ),
                    );
                  },
                  
                  label: const Text(
                    'تعديل الفحوصات',
                    style: TextStyle(color: Color(0xFF673AB7), fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Color(0xFF673AB7), width: 2 )
                    ),
                  ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF673AB7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تم إرسال الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ✅ دائرة خضراء بعلامة صح
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 70,
                  ),
                ),
                const SizedBox(height: 32),

                // ✅ عنوان النجاح
                const Text(
                  'تم رفع طلبك بنجاح!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // ✅ الرسالة التوضيحية
                const Text(
                  'سيتم إرسال المندوب إليك في أقرب وقت ممكن.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                const SizedBox(height: 40),
                // الأزرار السفلية: إلغاء الطلب / تعديل الطلب
                SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: Color(0xFF673AB7), width: 2
                              )
                            ),
                          ),
                          onPressed: () => _cancelOrder(context),
                          child: const Text('إلغاء الطلب', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF673AB7), width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                            // جلب بيانات المريض الحالية
                            try {
                              final patientDoc = await FirebaseFirestore.instance
                                  .collection('labToLap')
                                  .doc('global')
                                  .collection('patients')
                                  .doc(patientDocId)
                                  .get();
                              
                              if (patientDoc.exists) {
                                final data = patientDoc.data()!;
                                final name = data['name']?.toString() ?? '';
                                final phone = data['phone']?.toString() ?? '';
                                final barcode = data['barcode']?.toString() ?? '';
                                
                                _showEditOptionsDialog(context, name, phone, barcode);
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ في تحميل البيانات: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          child: const Text('تعديل الطلب', style: TextStyle(color: Color(0xFF673AB7))),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
