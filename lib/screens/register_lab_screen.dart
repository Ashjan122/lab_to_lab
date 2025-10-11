import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_dashboard_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'dart:convert';

class RegisterLabScreen extends StatefulWidget {
  const RegisterLabScreen({super.key});

  @override
  State<RegisterLabScreen> createState() => _RegisterLabScreenState();
}

class _RegisterLabScreenState extends State<RegisterLabScreen> {
  final FocusNode _labNameFocus = FocusNode();
  final FocusNode _userNameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _whatsFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _labName = TextEditingController();
  final TextEditingController _userName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whats = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  static const Color _primary = Color.fromARGB(255, 90, 138, 201);


  @override
  void dispose() {
    _labName.dispose();
    _userName.dispose();
    _phone.dispose();
    _whats.dispose();
    _address.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final String labName = _labName.text.trim();
      final String ownerName = _userName.text.trim();
      final String phoneRaw = _phone.text.trim();

      // Send welcome SMS immediately on press (non-blocking for overall flow)
      // If it fails, continue registration normally
      try {
        await _sendWelcomeSms(phone: phoneRaw, labName: labName)
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // ignore: avoid_print
        print('SMS immediate send error: $e');
      }

      // Prevent duplicate lab name
      final nameDup = await FirebaseFirestore.instance
          .collection('labToLap')
          .where('name', isEqualTo: labName)
          .limit(1)
          .get();
      if (nameDup.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اسم المعمل مستخدم مسبقاً'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // Prevent duplicate username
      final userDup = await FirebaseFirestore.instance
          .collection('labToLap')
          .where('ownerUserName', isEqualTo: ownerName)
          .limit(1)
          .get();
      if (userDup.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اسم المستخدم مستخدم مسبقاً'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      // determine next order
      final snap = await FirebaseFirestore.instance
          .collection('labToLap')
          .orderBy('order', descending: true)
          .limit(1)
          .get();
      int nextOrder = 1;
      if (snap.docs.isNotEmpty) {
        final dynamic highest = snap.docs.first.data()['order'];
        if (highest is int) {
          nextOrder = highest + 1;
        } else {
          final parsed = int.tryParse('$highest');
          nextOrder = (parsed != null ? parsed : 0) + 1;
        }
      }
      final doc = await FirebaseFirestore.instance.collection('labToLap').add({
        'name': labName,
        'ownerUserName': ownerName,
        'address': _address.text.trim(),
        'phone': phoneRaw,
        'whatsApp': _whats.text.trim().isEmpty ? null : _whats.text.trim(),
        'password': _password.text.trim(),
        'available': true,
        'order': nextOrder,
        'isApproved': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification for new lab contract
      final notificationTitle = 'تم إنشاء تعاقد جديد';
      final notificationBody = '''الاسم: $labName
العنوان: ${_address.text.trim()}
رقم الهاتف: $phoneRaw''';

      await FirebaseFirestore.instance.collection('push_requests').add({
        'topic': 'new_lab',
        'title': notificationTitle,
        'body': notificationBody,
        'labId': doc.id,
        'labName': labName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasContract', true);
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('lab_id', doc.id);
      await prefs.setString('labName', labName);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LabDashboardScreen(labId: doc.id, labName: labName)),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Format Sudan phone to 249XXXXXXXXX
  String _formatSudanPhone(String raw) {
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = '249${digits.substring(1)}';
    } else if (digits.startsWith('249')) {
      // already OK
    } else if (digits.length == 9) {
      // assume local without leading 0
      digits = '249$digits';
    }
    return digits;
  }

  Future<void> _sendWelcomeSms({required String phone, required String labName}) async {
    final String formatted = _formatSudanPhone(phone);

    // Use Airtel HTML GET API with provided credentials
    const String baseUrl = 'https://www.airtel.sd/api/html_send_sms/';
    const String username = 'jawda';
    const String password = 'Wda%^054J)(aDSn^';
    const String sender = 'Jawda';

    final String message = 'مرحبا بك $labName في خدمة Lab To Lab مع مركز الرومي الطبي\nسيتم اخطارك عند اعتماد التعاقد ورفع قائمة الاسعار';

    final String encodedText = Uri.encodeComponent(message);
    final String encodedSender = Uri.encodeComponent(sender);
    final String url = '${baseUrl}?username=${username}&password=${Uri.encodeComponent(password)}&phone_number=${formatted}&message=${encodedText}&sender=${encodedSender}';

    try {
      final response = await http.get(Uri.parse(url));
      // ignore: avoid_print
      print('Airtel HTML SMS resp: ${response.statusCode} ${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Airtel HTML SMS failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Airtel HTML SMS exception: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey.shade200,
                _primary.withOpacity(0.2),
                _primary.withOpacity(0.35),
              ],
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              SizedBox(height: 8),
                              SizedBox(
                                height: 80,
                                child: Image.asset('assets/images/logo.png'),
                              ),
                              const SizedBox(height: 12),
                              const Text('إنشاء تعاقد جديد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text(' أدخل بياناتك لإنشاء التعاقد', style: TextStyle(color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _labName,
                            focusNode: _labNameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_userNameFocus),
                            decoration: const InputDecoration(
                              labelText: 'اسم المعمل',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.biotech),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _userName,
                            focusNode: _userNameFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phone,
                            focusNode: _phoneFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_whatsFocus),
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _whats,
                            focusNode: _whatsFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_addressFocus),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'رقم الواتساب',
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(FontAwesomeIcons.whatsapp),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _address,
                            focusNode: _addressFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
                            decoration: const InputDecoration(
                              labelText: 'العنوان',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            focusNode: _passwordFocus,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_confirmPasswordFocus),
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6) ? 'على الأقل 6 أحرف' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPassword,
                            focusNode: _confirmPasswordFocus,
                            textInputAction: TextInputAction.done,
                            obscureText: _obscure,
                            decoration: const InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) => (v != _password.text.trim()) ? 'كلمتا المرور غير متطابقتين' : null,
                          ),
                        const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _submitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : const Text('إنشاء'),
                          ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            },
                            child: const Text('لديك تعاقد؟ تسجيل الدخول'),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


