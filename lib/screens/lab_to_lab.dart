import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:lab_to_lab_admin/screens/lab_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lab_to_lab_admin/screens/control_panal_screen.dart';
// ignore_for_file: unused_field, unused_element

const Color kLabPrimary = Color.fromARGB(255, 90, 138, 201);

class LabToLab extends StatefulWidget {
  const LabToLab({super.key});

  @override
  State<LabToLab> createState() => _LabToLabState();
}

class _LabToLabState extends State<LabToLab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsAppController = TextEditingController();
  final TextEditingController _orderController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _whatsAppFocus = FocusNode();
  final FocusNode _orderFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _showAddForm = false;
  bool _submitting = false;
  String? _editingLabId;
  String _selectedImageUrl = '';
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsAppController.dispose();
    _orderController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _nameFocus.dispose();
    _addressFocus.dispose();
    _phoneFocus.dispose();
    _whatsAppFocus.dispose();
    _orderFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImageFile == null) return;
    setState(() => _isUploadingImage = true);
    try {
      final fileName = 'labs/${DateTime.now().millisecondsSinceEpoch}_${path.basename(_selectedImageFile!.path)}';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final snapshot = await storageRef.putFile(_selectedImageFile!);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        _selectedImageUrl = downloadUrl;
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الصورة بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الصورة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  

  Future<void> _updateLab() async {
    if (_editingLabId == null) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      // Keep current order unless user edits it
      final currentDoc = await FirebaseFirestore.instance.collection('labToLap').doc(_editingLabId).get();
      final currentOrderDynamic = currentDoc.data()?['order'];
      int currentOrder = 999;
      if (currentOrderDynamic is int) {
        currentOrder = currentOrderDynamic;
      } else {
        currentOrder = int.tryParse('${currentOrderDynamic ?? ''}') ?? 999;
      }
      int newOrder = currentOrder;
      if (_orderController.text.trim().isNotEmpty) {
        final parsed = int.tryParse(_orderController.text.trim());
        if (parsed != null && parsed > 0) newOrder = parsed;
      }
      final currentImage = currentDoc.data()?['imageUrl'];
      await FirebaseFirestore.instance.collection('labToLap').doc(_editingLabId).update({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'whatsApp': _whatsAppController.text.trim(),
        'password': _passwordController.text.trim(),
        'order': newOrder,
        'imageUrl': _selectedImageUrl.isNotEmpty ? _selectedImageUrl : currentImage,
      });
      _clearForm();
      if (mounted) {
        setState(() {
          _editingLabId = null;
          _showAddForm = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث المعمل بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث المعمل: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _addressController.clear();
    _phoneController.clear();
    _whatsAppController.clear();
    _orderController.clear();
    _passwordController.clear();
    _selectedImageUrl = '';
    _selectedImageFile = null;
  }

  void _startEdit(String id, Map<String, dynamic> data) {
    setState(() {
      _editingLabId = id;
      _nameController.text = data['name']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _whatsAppController.text = data['whatsApp']?.toString() ?? '';
      _passwordController.text = data['password']?.toString() ?? '';
      _showAddForm = true;
      _selectedImageUrl = data['imageUrl']?.toString() ?? '';
      _selectedImageFile = null;
      final dynamic ord = data['order'];
      _orderController.text = ord == null ? '' : '$ord';
    });
  }

  Future<void> _toggleAvailability(String id, bool available) async {
    try {
      await FirebaseFirestore.instance.collection('labToLap').doc(id).update({'available': !available});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!available ? 'تم تفعيل المعمل' : 'تم إلغاء تفعيل المعمل'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث حالة المعمل: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  

  List<QueryDocumentSnapshot> _sortAndFilter(List<QueryDocumentSnapshot> docs) {
    final list = List<QueryDocumentSnapshot>.from(docs);
    list.sort((a, b) {
      try {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aAvail = aData['available'] as bool? ?? false;
        final bAvail = bData['available'] as bool? ?? false;
        if (aAvail != bAvail) return aAvail ? -1 : 1;
        final dynamic aOrderDyn = aData['order'];
        final dynamic bOrderDyn = bData['order'];
        final int aOrder = aOrderDyn is int ? aOrderDyn : int.tryParse('${aOrderDyn ?? ''}') ?? 999;
        final int bOrder = bOrderDyn is int ? bOrderDyn : int.tryParse('${bOrderDyn ?? ''}') ?? 999;
        return aOrder.compareTo(bOrder);
      } catch (_) {
        return 0;
      }
    });
    return list;
  }
   final TextEditingController _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';

  
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl
    , child:  Scaffold(
      appBar:  AppBar(
          title: const Text('المعامل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          leading: FutureBuilder<bool>(
            future: _shouldShowBackToControl(),
            builder: (context, snapshot) {
              final show = snapshot.data == true;
              if (!show) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'الرجوع للكنترول',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => ControlPanalScreen()),
                    (route) => false,
                  );
                },
              );
            },
          ),
          actions: const [],
        ),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            // Search bar by lab name
            Padding(
                    padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                                      setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'البحث باسم المعمل...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                      ),
                    ),
                  ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('labToLap').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('خطأ: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = _sortAndFilter(snapshot.data?.docs ?? []);
                  final filtered = docs.where((d) {
                    try {
                      final data = d.data() as Map<String, dynamic>;
                      final name = (data['name']?.toString() ?? '').toLowerCase();
                      if (_searchQuery.isEmpty) return true;
                      return name.contains(_searchQuery);
                    } catch (_) {
                      return true;
                    }
                  }).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.science, size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isEmpty ? 'لا توجد معامل مضافة بعد' : 'لا توجد نتائج للبحث',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                   return ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final d = filtered[index];
                      final data = d.data() as Map<String, dynamic>;
                      final name = data['name']?.toString() ?? '';
                      final address = data['address']?.toString() ?? '';
                      final phone = data['phone']?.toString() ?? '';
                      final whats = data['whatsApp']?.toString() ?? '';
                      final available = data['available'] as bool? ?? false;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('lab_id', d.id);
                            await prefs.setString('labName', name);
                            await prefs.setBool('fromControlPanel', true);
                            // ensure logged-in session persists to dashboard after restart
                            await prefs.setBool('isLoggedIn', true);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LabDashboardScreen(
                                  labId: d.id,
                                  labName: name,
                                ),
                              ),
                            );
                          },
                          leading: const Icon(Icons.science, color: kLabPrimary),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 20)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('العنوان: $address'),
                              Text('هاتف: $phone'),
                              Text('واتساب: $whats'),
                              Row(
                                children: [
                                  Icon(available ? Icons.check_circle : Icons.cancel, color: available ? Colors.green : Colors.red, size: 16),
                                  const SizedBox(width: 4),
                                  Text(available ? 'مفعل' : 'غير مفعل', style: TextStyle(color: available ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.sort, size: 16, color: kLabPrimary),
                                  const SizedBox(width: 4),
                                  Text('ترتيب: ${data['order'] ?? 999}', style: const TextStyle(color: kLabPrimary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              switch (value) {
                                case 'toggle':
                                  _toggleAvailability(d.id, available);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'toggle',
                                child: Row(children: [
                                  Icon(available ? Icons.block : Icons.check_circle, color: available ? Colors.orange : Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(available ? 'إلغاء التفعيل' : 'تفعيل'),
                                ]),
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
    ));
  }
}

Future<bool> _shouldShowBackToControl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('fromControlPanel') == true || (prefs.getString('userType') == 'controlUser');
}