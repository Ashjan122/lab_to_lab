import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lab_to_lab_admin/screens/lab_dashboard_screen.dart';
import 'package:lab_to_lab_admin/screens/control_samples_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/register_lab_screen.dart';
import 'package:lab_to_lab_admin/screens/control_panal_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userName = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  static const Color _primary = Color(0xFF673AB7);

  Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    // نفس طريقة صفحة الكنترول: إظهار الإصدار الكامل مع +
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  Future<void> _showSupportDialog() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('support')
          .doc('labNumbers')
          .get();
      final data = snap.data() ?? {};
      final numsDyn = data['numbers'];
      final List<String> numbers = numsDyn is List
          ? numsDyn
              .map((e) => e?.toString() ?? '')
              .where((e) => e.trim().isNotEmpty)
              .toList()
          : [];

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text(' أرقام الدعم الفني'),
            content: numbers.isEmpty
                ? const Text('لا توجد أرقام دعم حالياً')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(numbers.length, (index) {
                      final n = numbers[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${index + 1} -',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF673AB7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _launchPhone(n),
                              child: Text(
                                n,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text('تعذر تحميل أرقام الدعم: $e'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن فتح تطبيق الاتصال')),
      );
    }
  }

  @override
  void dispose() {
    _userName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final String inputUser = _userName.text.trim();
      final String inputPass = _password.text.trim();

      // 0) Try control user login from 'controlUsers' collection
      final controlSnap =
          await FirebaseFirestore.instance
              .collection('controlUsers')
              .where('userName', isEqualTo: inputUser)
              .where('userPassword', isEqualTo: inputPass)
              .limit(1)
              .get();
      if (controlSnap.docs.isNotEmpty) {
        final controlDoc = controlSnap.docs.first;
        final controlUserId = controlDoc.id;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userType', 'controlUser');
        await prefs.setString('control_user_id', controlUserId);
        // Save displayed user name for Control Panel greeting
        await prefs.setString(
          'userName',
          controlDoc.data()['userName']?.toString() ?? inputUser,
        );
        
        // Save FCM token for control user
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await FirebaseFirestore.instance
                .collection('controlUsers')
                .doc(controlUserId)
                .update({'fcmToken': fcmToken});
          }
        } catch (e) {
          print('Error saving FCM token: $e');
        }

        await prefs.remove('lab_id');
        await prefs.remove('labName');
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => ControlPanalScreen()),
          (route) => false,
        );
        return;
      }

      // 1) Try logging in as lab user from 'users' collection
      final userSnap =
          await FirebaseFirestore.instance
              .collection('users')
              .where('userName', isEqualTo: inputUser)
              .where('userPassword', isEqualTo: inputPass)
              .limit(1)
              .get();

      if (userSnap.docs.isNotEmpty) {
        final doc = userSnap.docs.first;
        final data = doc.data();
        final String labId = data['labId']?.toString() ?? '';
        final String labName = data['labName']?.toString() ?? 'المعمل';
        final String userType = data['userType']?.toString() ?? 'labUser';

        // Update login timestamps
        await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .update({
              'lastLoginAt': FieldValue.serverTimestamp(),
              'lastSeenAt': FieldValue.serverTimestamp(),
            });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setBool('hasContract', true);
        // Save userName for consistency even if not used in control panel
        await prefs.setString(
          'userName',
          data['userName']?.toString() ?? inputUser,
        );
        await prefs.setString('userPhone', data['userPhone']?.toString() ?? '');
        await prefs.setString('userType', userType);
        if (labId.isNotEmpty) await prefs.setString('lab_id', labId);
        await prefs.setString('labName', labName);

        if (!mounted) return;
        // Route based on userType
        if (userType == 'userDelivery') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ControlSamplesScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder:
                  (_) => LabDashboardScreen(labId: labId, labName: labName),
            ),
            (route) => false,
          );
        }
        return;
      }

      // 2) Fallback to lab owner credentials in 'labToLap'
      final snap =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .where('ownerUserName', isEqualTo: inputUser)
              .where('password', isEqualTo: inputPass)
              .limit(1)
              .get();
      if (snap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Directionality(
                textDirection: TextDirection.rtl,
                child: Text('بيانات غير صحيحة'),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final doc = snap.docs.first;
      final data = doc.data();
      final labName = data['name']?.toString() ?? 'المعمل';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setBool('hasContract', true);
      await prefs.setString('lab_id', doc.id);
      await prefs.setString('labName', labName);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LabDashboardScreen(labId: doc.id, labName: labName),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Text('خطأ: $e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                              const Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'ادخل بياناتك للمتابعة',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _userName,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator:
                                (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'مطلوب'
                                        : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed:
                                    () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator:
                                (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'مطلوب'
                                        : null,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton(
                            onPressed: _submitting ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child:
                                _submitting
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text('دخول'),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterLabScreen(),
                                  ),
                                );
                              },
                              child: const Text('ليس لديك تعاقد؟ إنشاء تعاقد'),
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  minimum: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _showSupportDialog,
                        child: const Text(
                          'الدعم الفني ',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                           
                            decoration: TextDecoration.underline,
                            
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<String>(
                        future: _getCurrentVersion(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox.shrink();
                          return Text(
                            'رقم الإصدار : ${snap.data}',
                            style: const TextStyle(color: Colors.black),
                          );
                        },
                      ),
                      const SizedBox(height: 15,),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
