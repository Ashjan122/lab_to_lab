import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ControlNotificationsScreen extends StatefulWidget {
  const ControlNotificationsScreen({super.key});

  @override
  State<ControlNotificationsScreen> createState() =>
      _ControlNotificationsScreenState();
}

class _ControlNotificationsScreenState
    extends State<ControlNotificationsScreen> {
  bool isSubscribed = false;
  bool isNewLabSubscribed = false;
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final controlUserId = prefs.getString('control_user_id');
    if (controlUserId == null) {
      // fallback to local if not control user
      final local = prefs.getBool('lab_order_subscribed');
      final localNewLab = prefs.getBool('new_lab_subscribed');
      if (local != null) {
        setState(() => isSubscribed = local);
      }
      if (localNewLab != null) {
        setState(() => isNewLabSubscribed = localNewLab);
      }
      return;
    }
    final doc =
        await FirebaseFirestore.instance
            .collection('controlUsers')
            .doc(controlUserId)
            .get();
    final status = doc.data()?['lab_order_subscribed'] == true;
    final newLabStatus = doc.data()?['new_lab_subscribed'] == true;
    setState(() {
      isSubscribed = status;
      isNewLabSubscribed = newLabStatus;
    });
  }

  // تبديل الاشتراك/إلغاء الاشتراك للمرضى
  void toggleSubscription() async {
    if (isSubscribed) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('lab_order');
      setState(() => isSubscribed = false);
      final prefs = await SharedPreferences.getInstance();
      final controlUserId = prefs.getString('control_user_id');
      if (controlUserId != null) {
        await FirebaseFirestore.instance
            .collection('controlUsers')
            .doc(controlUserId)
            .set({'lab_order_subscribed': false}, SetOptions(merge: true));
      } else {
        await prefs.setBool('lab_order_subscribed', false);
      }
    } else {
      await FirebaseMessaging.instance.subscribeToTopic('lab_order');
      setState(() => isSubscribed = true);
      final prefs = await SharedPreferences.getInstance();
      final controlUserId = prefs.getString('control_user_id');
      if (controlUserId != null) {
        await FirebaseFirestore.instance
            .collection('controlUsers')
            .doc(controlUserId)
            .set({'lab_order_subscribed': true}, SetOptions(merge: true));
      } else {
        await prefs.setBool('lab_order_subscribed', true);
      }
    }
  }

  // تبديل الاشتراك/إلغاء الاشتراك للتعاقدات الجديدة
  void toggleNewLabSubscription() async {
    if (isNewLabSubscribed) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('new_lab');
      setState(() => isNewLabSubscribed = false);
      final prefs = await SharedPreferences.getInstance();
      final controlUserId = prefs.getString('control_user_id');
      if (controlUserId != null) {
        await FirebaseFirestore.instance
            .collection('controlUsers')
            .doc(controlUserId)
            .set({'new_lab_subscribed': false}, SetOptions(merge: true));
      } else {
        await prefs.setBool('new_lab_subscribed', false);
      }
    } else {
      await FirebaseMessaging.instance.subscribeToTopic('new_lab');
      setState(() => isNewLabSubscribed = true);
      final prefs = await SharedPreferences.getInstance();
      final controlUserId = prefs.getString('control_user_id');
      if (controlUserId != null) {
        await FirebaseFirestore.instance
            .collection('controlUsers')
            .doc(controlUserId)
            .set({'new_lab_subscribed': true}, SetOptions(merge: true));
      } else {
        await prefs.setBool('new_lab_subscribed', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "الاشعارات",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ بطاقة عرض حالة الاشتراك للمرضى
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSubscribed ? Colors.green : Colors.orange,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSubscribed
                                ? Icons.check_circle
                                : Icons.notifications_off,
                            color: isSubscribed ? Colors.green : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isSubscribed
                                  ? 'أنت مشترك في تلقي إشعارات تسجيل مريض جديد'
                                  : 'أنت غير مشترك في تلقي إشعارات تسجيل مريض جديد',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ✅ زر الاشتراك / إلغاء الاشتراك داخل الكارد
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: toggleSubscription,
                          child: Text(
                            isSubscribed ? 'إلغاء الاشتراك' : 'اشتراك',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSubscribed ? Colors.green : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ✅ بطاقة عرض حالة الاشتراك للتعاقدات الجديدة
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isNewLabSubscribed ? Colors.green : Colors.orange,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isNewLabSubscribed
                                ? Icons.check_circle
                                : Icons.notifications_off,
                            color:
                                isNewLabSubscribed
                                    ? Colors.green
                                    : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isNewLabSubscribed
                                  ? 'أنت مشترك في تلقي إشعارات إنشاء تعاقد جديد'
                                  : 'أنت غير مشترك في تلقي إشعارات إنشاء تعاقد جديد',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // ✅ زر الاشتراك / إلغاء الاشتراك داخل الكارد
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: toggleNewLabSubscription,
                          child: Text(
                            isNewLabSubscribed ? 'إلغاء الاشتراك' : 'اشتراك',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isNewLabSubscribed
                                    ? Colors.green
                                    : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
