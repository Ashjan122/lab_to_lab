
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_select_tests_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LabNewSampleScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final String? existingPatientId;
  final String? existingName;
  final String? existingPhone;
  final String? existingBarcode;
  final bool isEditMode;

  const LabNewSampleScreen({
    super.key,
    required this.labId,
    required this.labName,
    this.existingPatientId,
    this.existingName,
    this.existingPhone,
    this.existingBarcode,
    this.isEditMode = false,
  });

  @override
  State<LabNewSampleScreen> createState() => _LabNewSampleScreenState();
}

class _LabNewSampleScreenState extends State<LabNewSampleScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _barcodeFocus = FocusNode();

  bool _saving = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
  if (_saving) return;
  if (!_formKey.currentState!.validate()) return;

  setState(() => _saving = true);

  try {
    // 1️⃣ تحقق من نسخة التطبيق أولاً
    final packageInfo = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

    final versionDoc = await FirebaseFirestore.instance
        .collection('appConfig')
        .doc('version3')
        .get();

    if (versionDoc.exists) {
      final lastVersion = versionDoc.data()?['lastVersion'] ?? 0;
      final updateUrl = versionDoc.data()?['updatrUrl'] ?? '';

      if (currentBuild < lastVersion) {
        if (!mounted) return;

        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text(
                "تحديث التطبيق",
                textAlign: TextAlign.end,
              ),
              content: const Text(
                "يرجى تحديث التطبيق إلى آخر إصدار للمتابعة",
                textAlign: TextAlign.end,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    final uri = Uri.parse(updateUrl);
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("فشل في فتح الرابط: $e")),
                      );
                    }
                  },
                  child: const Text("حدث الآن"),
                ),
              ],
            );
          },
        );

        return;
      }
    }

    // 2️⃣ إذا النسخة حديثة، استمر بالحفظ
    String patientDocId;

    if (widget.isEditMode && widget.existingPatientId != null) {
      // 🔄 تعديل مريض موجود
      patientDocId = widget.existingPatientId!;
      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc('global')
          .collection('patients')
          .doc(patientDocId)
          .update({
        'name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 🆕 إضافة مريض جديد — مع حماية ضد التكرار
      final firestore = FirebaseFirestore.instance;
      final patientsCol = firestore
          .collection('labToLap')
          .doc('global')
          .collection('patients');

      final docRef = await firestore.runTransaction((transaction) async {
        final counterRef = firestore
            .collection('labToLap')
            .doc('global')
            .collection('counters')
            .doc('patientId');

        final counterSnap = await transaction.get(counterRef);
        int nextId = 123;

        if (counterSnap.exists) {
          final current = counterSnap.data()?['lastPatientId'] ?? 122;
          nextId = (current is int ? current : int.parse(current.toString())) + 1;
        }

        // ✅ تحقق من أن الرقم غير مستخدم فعلاً
        bool foundFreeId = false;
        while (!foundFreeId) {
          final docCheck = await transaction.get(patientsCol.doc(nextId.toString()));
          if (docCheck.exists) {
            nextId++; // الرقم مستخدم → جرب التالي
          } else {
            foundFreeId = true;
          }
        }

        // 🧮 حدّث العداد لأحدث رقم مستخدم فعلاً
        transaction.update(counterRef, {'lastPatientId': nextId});

        final newPatientRef = patientsCol.doc(nextId.toString());

        final prefs = await SharedPreferences.getInstance();
        final savedUserName = prefs.getString('userName');
        final currentUserName = (savedUserName != null && savedUserName.trim().isNotEmpty)
            ? savedUserName
            : widget.labName;

        // 🩺 أضف المريض الجديد
        transaction.set(newPatientRef, {
          'id': nextId,
          'name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'barcode': _barcodeController.text.trim(),
          'labId': widget.labId,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          'ordered_by_name': currentUserName,
            
          'app_version': '${packageInfo.version}+${packageInfo.buildNumber}',

        });

        return newPatientRef;
      });

      patientDocId = docRef.id;
    }

    if (!mounted) return;

    if (!widget.isEditMode) {
      _fullNameController.clear();
      _phoneController.clear();
      _barcodeController.clear();
    }

    // 🔁 الانتقال إلى شاشة الفحوصات
    if (widget.isEditMode) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => LabSelectTestsScreen(
            labId: widget.labId,
            labName: widget.labName,
            patientId: patientDocId,
            skipNotification: true,
          ),
        ),
        (route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LabSelectTestsScreen(
            labId: widget.labId,
            labName: widget.labName,
            patientId: patientDocId,
            skipNotification: false,
          ),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _saving = false);
  }
}

  Future<void> _loadUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';
    _phoneController.text = phone;
  }

  Future<void> _loadExistingData() async {
    _fullNameController.text = widget.existingName ?? '';
    _phoneController.text = widget.existingPhone ?? '';
    _barcodeController.text = widget.existingBarcode ?? '';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _loadExistingData();
    } else {
      _loadUserPhone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditMode ? 'تعديل بيانات المريض' : 'عينة جديدة',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body:SafeArea(child: Container(
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
          width: double.infinity,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('اسم المريض',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullNameController,
                    focusNode: _nameFocus,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_phoneFocus),
                    validator: (v) {


if (v == null || v.trim().isEmpty) {
                        return 'يرجى إدخال الاسم';
                      }
                      if (v.trim().split(' ').length < 2) {
                        return 'يرجى إدخال اسمين على الأقل';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('رقم الهاتف',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_barcodeFocus),
                  ),
                  const SizedBox(height: 16),
                  const Text('الباركود',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _barcodeController,
                    focusNode: _barcodeFocus,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رقم الباركود',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF673AB7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(widget.isEditMode ? 'تحديث' : 'حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),),
      ),
    );
  }
}