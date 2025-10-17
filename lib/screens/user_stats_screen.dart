import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserStatsScreen extends StatelessWidget {
  const UserStatsScreen({super.key});

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _onlineThreshold() {
    return DateTime.now().subtract(const Duration(minutes: 5));
  }

  DateTime? _parseTs(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is int) return DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  bool _tsOnOrAfter(dynamic ts, DateTime dtLocal) {
    final t = _parseTs(ts);
    if (t == null) return false;
    return !t.toLocal().isBefore(dtLocal);
  }

  bool _tsIsToday(dynamic ts) {
    final t = _parseTs(ts)?.toLocal();
    if (t == null) return false;
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final usersCol = FirebaseFirestore.instance.collection('users');
    final todayStart = _startOfToday();
    final onlineFrom = _onlineThreshold();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text(
              'احصائيات المستخدمين',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: const Color(0xFF673AB7),
            centerTitle: true,
            bottom: const TabBar(
              tabs: [Tab(text: 'سجلوا اليوم'), Tab(text: 'متصلون الآن'),],
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black,
            ),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                usersCol.where('userType', isEqualTo: 'labUser').snapshots(),
            builder: (context, snap) {
              if (snap.hasError)
                return Center(child: Text('خطأ: ${snap.error}'));
              if (!snap.hasData)
                return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;

              final loggedInToday =
                  docs
                      .where(
                        (d) =>
                            _tsIsToday(d.data()['lastLoginAt']) ||
                            _tsOnOrAfter(d.data()['lastLoginAt'], todayStart),
                      )
                      .toList();
              final onlineNow =
                  docs
                      .where(
                        (d) => _tsOnOrAfter(d.data()['lastSeenAt'], onlineFrom),
                      )
                      .toList();

              Widget buildList(
                List<QueryDocumentSnapshot<Map<String, dynamic>>> list, {
                required bool showOnline,
              }) {
                return list.isEmpty
                    ? const Center(child: Text('لا يوجد مستخدمين'))
                    : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (_, i) {
                        final d = list[i];
                        final data = d.data();
                        final userName = data['userName']?.toString() ?? '';
                        final labName = data['labName']?.toString() ?? '';
                        final phone = data['userPhone']?.toString() ?? '';
                        final isOnline = _tsOnOrAfter(
                          data['lastSeenAt'],
                          onlineFrom,
                        );
                        return ListTile(
                          title: Text(
                            userName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (labName.isNotEmpty) Text('المعمل: $labName'),
                              Text(
                                phone.isEmpty ? 'بدون رقم' : 'الهاتف: $phone',
                              ),
                            ],
                          ),
                          trailing:
                              showOnline
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOnline
                                            ? Icons.circle
                                            : Icons.circle_outlined,
                                        size: 12,
                                        color:
                                            isOnline
                                                ? Colors.green
                                                : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOnline ? 'متصل' : 'غير متصل',
                                        style: TextStyle(
                                          color:
                                              isOnline
                                                  ? Colors.green
                                                  : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  )
                                  : null,
                        );
                      },
                    );
              }

              return TabBarView(
                children: [
                  buildList(loggedInToday, showOnline: false),
                  buildList(onlineNow, showOnline: true),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
