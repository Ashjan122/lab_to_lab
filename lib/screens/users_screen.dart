import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _userName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _editingUserId; // null => adding new
  bool _submitting = false;

  @override
  void dispose() {
    _userName.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _openUserDialog({DocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final bool isEdit = doc != null;
    if (isEdit) {
      final data = doc.data()!;
      _editingUserId = doc.id;
      _userName.text = data['userName']?.toString() ?? '';
      _phone.text = data['userPhone']?.toString() ?? '';
      _password.text = data['userPassword']?.toString() ?? '';
    } else {
      _editingUserId = null;
      _userName.clear();
      _phone.clear();
      _password.clear();
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'تعديل مستخدم توصيل' : 'إضافة مستخدم توصيل جديد'),
          content: Form(
            key: _formKey,
            child: SizedBox(
              width: 380,
              child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                  TextFormField(
                    controller: _userName,
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
                    controller: _password,
                obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    validator: (v) => (v == null || v.trim().length < 4) ? 'على الأقل 4 أحرف' : null,
                  ),
                ],
              ),
            ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
              onPressed: _submitting
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _submitting = true);
                      try {
                        final Map<String, dynamic> payload = {
                          'userName': _userName.text.trim(),
                          'userPhone': _phone.text.trim(),
                          'userPassword': _password.text.trim(),
                          'userType': 'userDelivery',
                          // optional linking for display consistency if needed
                        };
                        if (isEdit) {
                          await FirebaseFirestore.instance.collection('users').doc(_editingUserId).update(payload);
                } else {
                          await FirebaseFirestore.instance.collection('users').add(payload);
                        }
                        if (mounted) Navigator.of(context).pop();
              } catch (e) {
                        if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                );
              }
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
              child: Text(isEdit ? 'حفظ' : 'إضافة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'المستخدمين',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
          actions: [
            Builder(
              builder: (context) {
                final controller = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return controller.index == 1
                        ? IconButton(
                            tooltip: 'إضافة مستخدم توصيل',
                            onPressed: () => _openUserDialog(),
                            icon: const Icon(Icons.add, color: Colors.white),
                          )
                        : const SizedBox.shrink();
                  },
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            const TabBar(
              indicatorColor: Color(0xFF673AB7),
              labelColor: Color(0xFF673AB7),
              unselectedLabelColor: Colors.black,
              tabs: [
                Tab(text: 'مستخدمي المعامل'),
                Tab(text: 'مستخدمي التوصيل'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Lab users
                  _UsersList(stream: FirebaseFirestore.instance.collection('users').where('userType', isEqualTo: 'labUser').snapshots(), onEdit: null, showLabName: true),
                  // Delivery users (editable)
                    _UsersList(
                    stream: FirebaseFirestore.instance.collection('users').where('userType', isEqualTo: 'userDelivery').snapshots(),
                      onEdit: (doc) => _openUserDialog(doc: doc),
                      showLabName: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _UsersList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final void Function(DocumentSnapshot<Map<String, dynamic>> doc)? onEdit;
  final bool showLabName;
  const _UsersList({required this.stream, this.onEdit, this.showLabName = true});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('خطأ: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(child: Text('لا يوجد مستخدمين'));
            }
            return ListView.separated(
              itemCount: docs.length,
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final userData = doc.data();
                final userName = userData['userName']?.toString() ?? '';
            final labName = userData['labName']?.toString() ?? '';
                final phone = userData['userPhone']?.toString() ?? '';

                return Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                      color: const Color(0xFF673AB7),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                        color: Color(0xFF673AB7),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showLabName && labName.isNotEmpty)
                      Text(
                        labName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Text(
                        'الهاتف: $phone',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                trailing: onEdit == null
                    ? null
                    : IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => onEdit!(doc),
                    ),
                  ),
                );
              },
            );
          },
    );
  }
}
