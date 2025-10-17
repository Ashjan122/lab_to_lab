import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/chat_screen.dart';
import 'dart:collection';

class SupportNumbersScreen extends StatefulWidget {
  const SupportNumbersScreen({super.key});

  @override
  State<SupportNumbersScreen> createState() => _SupportNumbersScreenState();
}

class _SupportNumbersScreenState extends State<SupportNumbersScreen> {
  bool _saving = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _promptAddNumber() async {
    final TextEditingController ctrl = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('إضافة رقم دعم فني'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.left,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('إضافة'),
              ),
            ],
          ),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    setState(() => _saving = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('support')
          .doc('labNumbers');
      final doc = await docRef.get();
      final List<dynamic> numbers =
          (doc.data()?['numbers'] as List<dynamic>? ?? []).toList();
      numbers.add(confirmed);
      await docRef.set({'numbers': numbers}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إضافة الرقم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editNumber(List<dynamic> currentNumbers, int index) async {
    final TextEditingController editCtrl = TextEditingController(
      text: currentNumbers[index].toString(),
    );
    final newValue = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تعديل الرقم'),
            content: TextField(
              controller: editCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
                child: const Text('حفظ'),
              ),
            ],
          ),
    );
    if (newValue == null || newValue.isEmpty) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('support')
          .doc('labNumbers');
      final updated = currentNumbers.toList();
      updated[index] = newValue;
      await docRef.set({'numbers': updated}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تعديل الرقم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNumber(List<dynamic> currentNumbers, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف الرقم: ${currentNumbers[index]}؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('support')
          .doc('labNumbers');
      final updated = currentNumbers.toList();
      updated.removeAt(index);
      await docRef.set({'numbers': updated}, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حذف الرقم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF673AB7),
            ),
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
          actions: [
            IconButton(
              tooltip: 'إضافة رقم',
              onPressed: _saving ? null : _promptAddNumber,
              icon: const Icon(
                Icons.add,
                color: Color(0xFF673AB7),
              ),
            ),
          ],
            bottom: const TabBar(
              indicatorColor: Color(0xFF673AB7),
              labelColor: Color(0xFF673AB7),
              unselectedLabelColor: Colors.grey,
              tabs: [
                
                Tab(text: 'الدردشة'),
                Tab(text: 'أرقام الدعم'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              const _ControlChatLabsTab(),
              _SupportNumbersList(
                saving: _saving,
                onEdit: _editNumber,
                onDelete: _deleteNumber,
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportNumbersList extends StatelessWidget {
  final bool saving;
  final Future<void> Function(List<dynamic>, int) onEdit;
  final Future<void> Function(List<dynamic>, int) onDelete;
  const _SupportNumbersList({required this.saving, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
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
                  final List<dynamic> numbers = (data['numbers'] as List<dynamic>? ?? []);
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
                                  Text(value, textDirection: TextDirection.ltr),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'تعديل',
                                onPressed: () => onEdit(numbers, index),
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Color(0xFF673AB7),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'حذف',
                                onPressed: () => onDelete(numbers, index),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
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
          ),
    );
  }
}

class _ControlChatLabsTab extends StatelessWidget {
  const _ControlChatLabsTab();

  Future<Map<String, String>> _getControlUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('control_user_id') ?? '';
    final userName = prefs.getString('userName') ?? 'الكنترول';
    return {'id': userId, 'name': userName};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _getControlUser(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final currentId = userSnap.data!['id'] ?? '';
        final currentName = userSnap.data!['name'] ?? 'الكنترول';

        // اعرض فقط المعامل التي أرسلت رسائل إلى هذا المستخدم الكنترول
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messages')
              .where('receiverId', isEqualTo: currentId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final msgs = snapshot.data!.docs;
            // تجميع معرفات المعامل التي أرسلت رسائل (senderId)
            final LinkedHashSet<String> labIds = LinkedHashSet<String>();
            for (final doc in msgs) {
              final data = doc.data() as Map<String, dynamic>;
              final senderId = data['senderId']?.toString() ?? '';
              if (senderId.isNotEmpty) labIds.add(senderId);
            }
            final ids = labIds.toList();
            if (ids.isEmpty) {
              return const Center(child: Text('لا توجد محادثات مع أي معمل بعد.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ids.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final labId = ids[index];
                return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('labToLap')
                      .doc(labId)
                      .get(),
                  builder: (context, labSnap) {
                    if (!labSnap.hasData) {
                      return const SizedBox.shrink();
                    }
                    final snapData = labSnap.data;
                    if (snapData == null || !snapData.exists) {
                      return const SizedBox.shrink();
                    }
                    final labData = snapData.data();
                    final labName = labData?['name']?.toString() ?? 'معمل';
                    return Card(
                      child: ListTile(
                       
                        title: Text(labName),
                        trailing: const Icon(Icons.chat),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(
                                labId: currentId,
                                labName: currentName,
                                receiverId: labId,
                                receiverName: labName,
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
          },
        );
      },
    );
  }
}
