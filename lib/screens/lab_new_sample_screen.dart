import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_select_tests_screen.dart';

class LabNewSampleScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const LabNewSampleScreen({super.key, required this.labId, required this.labName});


  @override
  State<LabNewSampleScreen> createState() => _LabNewSampleScreenState();
}

class _LabNewSampleScreenState extends State<LabNewSampleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final patientsCol = FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients');

      // get next sequential id starting from 1
      final lastSnap = await patientsCol.orderBy('id', descending: true).limit(1).get();
      int nextId = 1;
      if (lastSnap.docs.isNotEmpty) {
        final dyn = lastSnap.docs.first.data()['id'];
        final asInt = (dyn is int) ? dyn : int.tryParse('${dyn ?? ''}') ?? 0;
        nextId = asInt + 1;
      }

      final docRef = patientsCol.doc(nextId.toString());
      await docRef.set({
        'id': nextId,
        'name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'labId': widget.labId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      if (!mounted) return;
      _fullNameController.clear();
      _phoneController.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LabSelectTestsScreen(
            labId: widget.labId,
            labName: widget.labName,
            patientId: docRef.id,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عينة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اسم المريض', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الثلاثي',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
  if (v == null || v.trim().isEmpty) {
    return 'يرجى إدخال الاسم الثلاثي';
  }
  if (v.trim().split(' ').length < 3) {
    return 'يرجى إدخال الاسم الثلاثي';
  }
  return null;
},

                ),
                const SizedBox(height: 16),
                Text('رقم الهاتف', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
  if (v == null || v.trim().isEmpty) {
    return 'يرجى إدخال رقم الهاتف';
  }
  if (v.trim().length < 8) {
    return 'يرجى إدخال رقم هاتف صحيح';
  }
  return null;
},

                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 90, 138, 201),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('حفظ'),
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