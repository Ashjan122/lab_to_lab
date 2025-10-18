import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LabOrderReceivedNotificationsScreen extends StatefulWidget {
  const LabOrderReceivedNotificationsScreen({super.key});

  @override
  State<LabOrderReceivedNotificationsScreen> createState() =>
      _LabOrderReceivedNotificationsScreenState();
}

class _LabOrderReceivedNotificationsScreenState
    extends State<LabOrderReceivedNotificationsScreen> {
  bool isSubscribed = false;
  String? labId;
  String? labName;
  String? userName;
  String? userType;
  String? _topic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    labId = prefs.getString('lab_id');
    labName = prefs.getString('labName');
    userName = prefs.getString('userName');
    userType = prefs.getString('userType');

    // Check subscription status based on user type
    if (userType == 'labUser' && userName != null) {
      // For lab users, check in users collection
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .where('userName', isEqualTo: userName)
              .limit(1)
              .get();
      if (userDoc.docs.isNotEmpty) {
        // derive labId from user document for lab-specific topic
        labId = userDoc.docs.first.data()['labId']?.toString();
        setState(() {
          isSubscribed =
              userDoc.docs.first.data()['lab_order_received_subscribed'] ??
              false;
        });
      }
    } else if (labId != null) {
      // For lab owners, check in labToLap collection
      final labDoc =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(labId)
              .get();
      if (labDoc.exists) {
        setState(() {
          isSubscribed =
              labDoc.data()?['lab_order_received_subscribed'] ?? false;
        });
      }
    }

    // compute topic if we have a labId
    if (labId != null && labId!.isNotEmpty) {
      _topic = labId!;
    } else {
      _topic = null;
    }

    // Auto-subscribe to current topic if previously marked subscribed
    if (_topic != null && isSubscribed) {
      try {
        await FirebaseMessaging.instance.subscribeToTopic(_topic!);
      } catch (_) {}
    }
  }

  Future<void> _save(bool status) async {
    if (userType == 'labUser' && userName != null) {
      // For lab users, save in users collection
      final userQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('userName', isEqualTo: userName)
              .limit(1)
              .get();
      if (userQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userQuery.docs.first.id)
            .update({'lab_order_received_subscribed': status});
      }
    } else if (labId != null) {
      // For lab owners, save in labToLap collection
      await FirebaseFirestore.instance.collection('labToLap').doc(labId).update(
        {'lab_order_received_subscribed': status},
      );
    }
  }

  Future<void> _toggle() async {
    if (_topic == null) return;
    if (isSubscribed) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(_topic!);
      await _save(false);
      setState(() => isSubscribed = false);
    } else {
      await FirebaseMessaging.instance.subscribeToTopic(_topic!);
      await _save(true);
      setState(() => isSubscribed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الإشعارات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body:Container(
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
            child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          const Expanded(
                            child: Text(
                              'الاشتراك في الإشعارات',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isSubscribed ? Colors.green : Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            isSubscribed ? 'إلغاء الاشتراك' : 'اشتراك',
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
      ),),
    );
  }
}
