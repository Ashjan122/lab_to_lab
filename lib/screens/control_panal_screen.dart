import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lab_to_lab_admin/screens/control_notifications_screen.dart';
import 'package:lab_to_lab_admin/screens/control_samples_screen.dart';
import 'package:lab_to_lab_admin/screens/lab_to_lab.dart';
import 'package:lab_to_lab_admin/screens/login_screen.dart';
import 'package:lab_to_lab_admin/screens/patients_screen.dart';
import 'package:lab_to_lab_admin/screens/support_numbers_screen.dart';
import 'package:lab_to_lab_admin/screens/user_stats_screen.dart';
import 'package:lab_to_lab_admin/screens/claim_labs_picker_screen.dart';
import 'package:lab_to_lab_admin/screens/users_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';


class ControlPanalScreen extends StatefulWidget {
  const ControlPanalScreen({super.key});

  @override
  State<ControlPanalScreen> createState() => _ControlPanalScreenState();
}

class _ControlPanalScreenState extends State<ControlPanalScreen> with WidgetsBindingObserver {
  String? _controlUserId;

  int? _lastSeenPatientsMs;
  String? _userName;
  final ImagePicker _picker = ImagePicker();
  String? _profileImageUrl;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLastSeenPatients();
    _loadUserName();
    _loadControlUserIdAndSetOnline();
  }
Future<void> _loadControlUserIdAndSetOnline() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getString('control_user_id');
  if (id != null) {
    setState(() {
      _controlUserId = id;
    });
    _setOnlineStatus(true); // أول ما يدخل: أونلاين
  }
}
Future<void> _setOnlineStatus(bool isOnline) async {
  if (_controlUserId == null) return;

  await FirebaseFirestore.instance
      .collection('controlUsers')
      .doc(_controlUserId)
      .update({
    'isOnline': isOnline,
    'lastSeen': FieldValue.serverTimestamp(),
  });
}
@override
void dispose() {
  _setOnlineStatus(false); // عند الخروج: أوفلاين
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _setOnlineStatus(true); // عاد للتطبيق
  } else {
    _setOnlineStatus(false); // دخل خلفية أو أغلق
  }
}

  Future<void> _loadLastSeenPatients() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeenPatientsMs = prefs.getInt('control_last_seen_patients');
    });
  }

  Future<void> _loadUserName() async {
  final prefs = await SharedPreferences.getInstance();
  String? name = prefs.getString('userName');
  String? img = prefs.getString('profileImageUrl');
  final controlUserId = prefs.getString('control_user_id');

  if ((name == null || name.isEmpty) || (img == null || img.isEmpty)) {
    if (controlUserId != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('controlUsers')
            .doc(controlUserId)
            .get();
        if (snap.exists) {
          name ??= snap.data()?['userName']?.toString();
          img ??= snap.data()?['profileImageUrl']?.toString();

          if (name != null && name.isNotEmpty) {
            await prefs.setString('userName', name);
          }
          if (img != null && img.isNotEmpty) {
            await prefs.setString('profileImageUrl', img);
          }
        }
      } catch (_) {}
    }
  }

  if (!mounted) return;
  setState(() {
    _userName = name;
    _profileImageUrl = img;
  });
}
Future<void> _pickAndUploadProfileImage() async {
  if (_controlUserId == null) return;

  final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
  if (picked == null) return;

  final file = File(picked.path);
  try {
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_images/$_controlUserId.jpg');

    await ref.putFile(file);
    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('controlUsers')
        .doc(_controlUserId)
        .update({'profileImageUrl': url});

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImageUrl', url);

    setState(() {
      _profileImageUrl = url;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث الصورة')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('فشل في رفع الصورة: $e')),
    );
  }
}


  Widget _buildControlCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final BorderRadius cardRadius = BorderRadius.circular(12);
    return 
        Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: cardRadius),
      child: InkWell(
        borderRadius: cardRadius,
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Row(
            
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color ?? const Color(0xFF673AB7),
                  size: 25,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsCardWithBadge() {
    final BorderRadius cardRadius = BorderRadius.circular(12);
    final Color primary = const Color(0xFF673AB7);
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);
    final int thresholdMs =
        _lastSeenPatientsMs ?? startOfToday.millisecondsSinceEpoch;
    final Timestamp thresholdTs = Timestamp.fromMillisecondsSinceEpoch(
      thresholdMs,
    );

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('labToLap')
              .doc('global')
              .collection('patients')
              .where('createdAt', isGreaterThanOrEqualTo: thresholdTs)
              .snapshots(),
      builder: (context, snap) {
        final int count = snap.hasData ? snap.data!.docs.length : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: cardRadius),
              child: InkWell(
                borderRadius: cardRadius,
                onTap: () async {
                  final nowMs = DateTime.now().millisecondsSinceEpoch;
                  setState(() {
                    _lastSeenPatientsMs = nowMs; // hide badge instantly
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setInt('control_last_seen_patients', nowMs);
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientsScreen()),
                  );
                },
                child: SizedBox(
                  height: 72,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    child: Row(
                    
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(FontAwesomeIcons.user, color: primary, size: 25),
                        
                        const Text(
                          'المرضى',
                          
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMessagesCardWithBadge() {
    final BorderRadius cardRadius = BorderRadius.circular(12);
    final Color primary = const Color(0xFF673AB7);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: _controlUserId ?? '')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, chatSnap) {
        final int unreadChats = chatSnap.hasData ? chatSnap.data!.docs.length : 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: cardRadius),
              child: InkWell(
                borderRadius: cardRadius,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SupportNumbersScreen()),
                  );
                },
                child: SizedBox(
                  height: 72,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.chat, color: Color(0xFF673AB7), size: 25),
                        const Text(
                          'صندوق المراسلات',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (unreadChats > 0)
              Positioned(
                top: -4,
                left: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$unreadChats',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
  void _showEditProfileDialog() {
  final TextEditingController nameController = TextEditingController(text: _userName ?? '');
  final TextEditingController passwordController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('الملف الشخصي'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // حقل الاسم
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              ),
              const SizedBox(height: 10),

              // حقل تغيير كلمة المرور
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'تغيير كلمة المرور',
                  hintText: 'اتركه فارغ إذا لا تريد التغيير',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              final newPassword = passwordController.text.trim();

              if (_controlUserId == null) return;

              final updates = <String, dynamic>{};

              if (newName.isNotEmpty) {
                updates['userName'] = newName;
              }

              if (newPassword.isNotEmpty) {
                updates['userPassword'] = newPassword;
              }

              if (updates.isNotEmpty) {
                try {
                  await FirebaseFirestore.instance
                      .collection('controlUsers')
                      .doc(_controlUserId)
                      .update(updates);

                  final prefs = await SharedPreferences.getInstance();
                  if (newName.isNotEmpty) {
                    await prefs.setString('userName', newName);
                  }

                  setState(() {
                    if (newName.isNotEmpty) _userName = newName;
                  });

                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ التعديلات بنجاح')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل في التحديث: $e')),
                  );
                }
              } else {
                Navigator.of(context).pop(); // لم يتم تغيير شيء
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "لوحة تحكم الكنترول",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF673AB7),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => Scaffold.of(ctx).openDrawer(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.25),
                backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ControlNotificationsScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
  child: SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ✅ رأس الدروار بصورة واسم المستخدم
        Container(
          color: const Color(0xFF673AB7),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAndUploadProfileImage,
                child: CircleAvatar(
                  radius: 45, // حجم أكبر
                  backgroundColor: Colors.white,
                  backgroundImage: (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                      ? NetworkImage(_profileImageUrl!)
                      : null,
                  child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Color(0xFF673AB7), size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _userName ?? 'المستخدم',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // ✅ زر الملف الشخصي
ListTile(
  leading: const Icon(Icons.person, color: Color(0xFF673AB7)),
  title: const Text('الملف الشخصي'),
  onTap: () {
    Navigator.pop(context); // يغلق الدروار
    _showEditProfileDialog(); // يظهر الديالوق
  },
),


        // 🟪 باقي العناصر هنا (لو فيه أي عناصر إضافية قبل تسجيل الخروج)

        const Spacer(),

        // ✅ زر تسجيل الخروج داخل إطار
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('userType');
                await prefs.remove('lab_id');
                await prefs.remove('labName');
                await prefs.remove('fromControlPanel');
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 24), // هامش سفلي بسيط
      ],
    ),
  ),
),

      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/image.png'),
            // عرض الصورة بحجمها الأصلي وتكرارها لتغطية الشاشة بدون تكبير
            fit: BoxFit.none,
            alignment: Alignment.topLeft,
            repeat: ImageRepeat.repeat,
            opacity: 0.20,
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // تمت إزالة معلومات المستخدم من البودي — أصبحت داخل الدروار

            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
                childAspectRatio: 4,
                children: [
                  _buildControlCard(
                    icon: Icons.biotech,
                    title: 'المعامل',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LabToLab()),
                      );
                    },
                  ),
                  _buildPatientsCardWithBadge(),
                  _buildMessagesCardWithBadge(),
                  _buildControlCard(icon: FontAwesomeIcons.vials,
                        title: 'عينات اليوم', 
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ControlSamplesScreen()));
                        },),
                  _buildControlCard(
                    icon: Icons.query_stats,
                    title: 'احصائيات ',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserStatsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildControlCard(
                    icon: Icons.people_alt,
                    title: 'المستخدمين',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UsersScreen()),
                      );
                    },
                  ),
                  _buildControlCard(
                    icon: Icons.receipt_long,
                    title: 'المطالبة',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClaimLabsPickerScreen(),
                        ),
                      );
                    },
                  ),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}
