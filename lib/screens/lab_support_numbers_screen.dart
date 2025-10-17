import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/chat_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LabSupportNumbersScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const LabSupportNumbersScreen({
    super.key,
    required this.labId,
    required this.labName,
  });

  @override
  State<LabSupportNumbersScreen> createState() =>
      _LabSupportNumbersScreenState();
}

class _LabSupportNumbersScreenState extends State<LabSupportNumbersScreen> {
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح تطبيق الهاتف'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSupportNumbersTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('support')
                      .doc('labNumbers')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data!.data() ?? {};
                final List<dynamic> numbers =
                    (data['numbers'] as List<dynamic>? ?? []);
                if (numbers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.support_agent,
                          color: Colors.grey[400],
                          size: 64,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد أرقام مسجلة',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: numbers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final value = numbers[index].toString();
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Row(
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
                            GestureDetector(
                              onTap: () => _makePhoneCall(value),
                              child: Text(
                                value,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF673AB7)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'الدعم الفني',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF673AB7),
                fontSize: 24,
              ),
            ),
            centerTitle: true,
            bottom: const TabBar(
              indicatorColor: Color(0xFF673AB7),
              labelColor: Color(0xFF673AB7),
              unselectedLabelColor: Colors.grey,
              tabs: [Tab(text: 'الدردشة'), Tab(text: 'أرقام الدعم')],
            ),
          ),
          body: TabBarView(
            children: [
              ChatUsersTab(labId: widget.labId, labName: widget.labName),
              _buildSupportNumbersTab(),
              
            ],
          ),
        ),
      ),
    );
  }
}

class ChatUsersTab extends StatelessWidget {
  final String labId;
  final String labName;
  const ChatUsersTab({super.key, required this.labId, required this.labName});
  Widget _buildLastSeenText(dynamic timestamp) {
  if (timestamp == null || timestamp is! Timestamp) {
    return const Text(
      'غير متصل',
      style: TextStyle(color: Colors.grey, fontSize: 12),
    );
  }

  final lastSeen = timestamp.toDate();
  final duration = DateTime.now().difference(lastSeen);

  String text;
  if (duration.inMinutes < 1) {
    text = 'نشط قبل لحظات';
  } else if (duration.inMinutes < 60) {
    text = 'نشط قبل ${duration.inMinutes} دقيقة';
  } else if (duration.inHours < 24) {
    text = 'نشط قبل ${duration.inHours} ساعة';
  } else {
    text = 'نشط بتاريخ ${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  return Text(
    text,
    style: const TextStyle(color: Colors.grey, fontSize: 12),
  );
}


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('controlUsers')
              .where('userType', isEqualTo: 'control')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return const Center(child: Text('لا يوجد مستخدمي كنترول حالياً.'));
        }
        // ترتيب المتصلين أولاً
users.sort((a, b) {
  final aOnline = (a.data() as Map<String, dynamic>)['isOnline'] ?? false;
  final bOnline = (b.data() as Map<String, dynamic>)['isOnline'] ?? false;

  // المتصلين في الأعلى
  if (aOnline && !bOnline) return -1;
  if (!aOnline && bOnline) return 1;
  return 0;
});


        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = users[index].data() as Map<String, dynamic>;
            final name = data['userName'] ?? 'بدون اسم';

           return Card(
  child: ListTile(
    leading: Stack(
  children: [
    CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      backgroundImage: (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty)
          ? NetworkImage(data['profileImageUrl'])
          : null,
      child: (data['profileImageUrl'] == null || data['profileImageUrl'].toString().isEmpty)
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    ),
    if ((data['isOnline'] ?? false) == true)
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
  ],
),

    title: Text(name),
    subtitle: (data['isOnline'] ?? false)
        ? const Text(
            'متصل الآن',
            style: TextStyle(color: Colors.green, fontSize: 12),
          )
        : _buildLastSeenText(data['lastSeen']),
    trailing: const Icon(Icons.chat),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            labId: labId,
            labName: labName,
            receiverId: users[index].id,
            receiverName: name,
          ),
        ),
      );
    },
  ),
);

          },
        );
      },
    );
  }
}
