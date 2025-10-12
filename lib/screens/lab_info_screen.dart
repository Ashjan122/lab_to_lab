import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Global variable to track if user came from control panel
bool globalFromControlPanel = false;

class LabInfoScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const LabInfoScreen({super.key, required this.labId, required this.labName});

  @override
  State<LabInfoScreen> createState() => _LabInfoScreenState();
}

class _LabInfoScreenState extends State<LabInfoScreen>
    with WidgetsBindingObserver, RouteAware {
  bool _loading = true;
  bool _isEditing = false;
  bool _saving = false;
  bool _fromControlPanel = false;
  Map<String, dynamic>? _labData;
  File? _selectedImage;
  String? _imageUrl;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLabData();
    _checkFromControlPanel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check again when returning from sub-screens
    _checkFromControlPanel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check again when app resumes
      _checkFromControlPanel();
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // This is called when returning from a sub-screen
    print('Returned from sub-screen, checking fromControlPanel again');
    _checkFromControlPanel();
  }

  @override
  void didPushNext() {
    super.didPushNext();
    // This is called when navigating to a sub-screen
    print('Navigating to sub-screen');
  }

  Future<void> _loadLabData() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(widget.labId)
              .get();

      if (mounted) {
        setState(() {
          _labData = doc.data();
          _imageUrl = _labData?['imageUrl'];
          _phoneController.text = _labData?['phone']?.toString() ?? '';
          _whatsappController.text = _labData?['whatsapp']?.toString() ?? '';
          _addressController.text = _labData?['address']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
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
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Remove any non-digit characters and add country code if needed
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!cleanPhone.startsWith('966')) {
      cleanPhone = '966$cleanPhone';
    }

    final Uri whatsappUri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح واتساب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkFromControlPanel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fromControlPanel = prefs.getBool('fromControlPanel') ?? false;
      print('Checking fromControlPanel: $fromControlPanel'); // Debug log

      // Update global variable
      globalFromControlPanel = fromControlPanel;

      if (mounted) {
        setState(() {
          _fromControlPanel = fromControlPanel;
        });
      }
    } catch (e) {
      print('Error checking fromControlPanel: $e'); // Debug log
      // Use global variable as fallback
      if (mounted) {
        setState(() {
          _fromControlPanel = globalFromControlPanel;
        });
      }
    }
  }

  Future<void> _goBackToDashboard() async {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _imageUrl;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('lab_images')
          .child(
            '${widget.labId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

      final uploadTask = ref.putFile(_selectedImage!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveData() async {
    setState(() => _saving = true);

    try {
      String? newImageUrl = await _uploadImage();

      await FirebaseFirestore.instance
          .collection('labToLap')
          .doc(widget.labId)
          .update({
            'phone': _phoneController.text.trim(),
            'whatsapp': _whatsappController.text.trim(),
            'address': _addressController.text.trim(),
            if (newImageUrl != null) 'imageUrl': newImageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          _isEditing = false;
          _selectedImage = null;
          if (newImageUrl != null) _imageUrl = newImageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث البيانات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التحديث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _selectedImage = null;
      _phoneController.text = _labData?['phone']?.toString() ?? '';
      _whatsappController.text =
          _labData?['whatsapp']?.toString() ?? '0991961111';
      _addressController.text = _labData?['address']?.toString() ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check fromControlPanel on every build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (globalFromControlPanel != _fromControlPanel) {
        setState(() {
          _fromControlPanel = globalFromControlPanel;
        });
      }
    });
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? 'تعديل بيانات ${widget.labName}'
                : 'بيانات ${widget.labName}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color.fromARGB(255, 90, 138, 201),
          centerTitle: true,
          leading:
              _fromControlPanel
                  ? IconButton(
                    onPressed: _goBackToDashboard,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'العودة للوحة التحكم',
                  )
                  : null,
          actions:
              _isEditing
                  ? [
                    IconButton(
                      onPressed: _saving ? null : _saveData,
                      icon:
                          _saving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.save, color: Colors.white),
                      tooltip: 'حفظ',
                    ),
                    IconButton(
                      onPressed: _saving ? null : _cancelEdit,
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'إلغاء',
                    ),
                  ]
                  : [
                    IconButton(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit, color: Colors.white),
                      tooltip: 'تعديل البيانات',
                    ),
                  ],
        ),
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _labData == null
                ? const Center(child: Text('لا توجد بيانات متاحة'))
                : _isEditing
                ? _buildEditView()
                : _buildViewMode(),
      ),
    );
  }

  Widget _buildViewMode() {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Lab Image and Name (centered like patient info)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lab Image
                if (_imageUrl != null)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: const Color(0xFF1976D2),
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(57),
                      child: Image.network(
                        _imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.business,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(60),
                      border: Border.all(
                        color: const Color(0xFF1976D2),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.business,
                      size: 50,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(height: 16),

                // Lab Name
                Text(
                  _labData!['name']?.toString() ?? widget.labName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Lab Information List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: _getInfoItems().length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (context, i) {
                final item = _getInfoItems()[i];
                return _buildInfoRow(
                  icon: item['icon'],
                  title: item['title'],
                  content: item['content'],
                  onTap: item['onTap'],
                  isClickable: item['isClickable'],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Lab Image
          Center(
            child: GestureDetector(
              onTap: () => _showImagePicker(),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: const Color(0xFF1976D2), width: 3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(57),
                  child:
                      _selectedImage != null
                          ? Image.file(_selectedImage!, fit: BoxFit.cover)
                          : _imageUrl != null
                          ? Image.network(
                            _imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.business,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                          : Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.business,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط لتغيير الصورة',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Lab Name (read-only)
          TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'اسم المعمل',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            controller: TextEditingController(
              text: _labData!['name']?.toString() ?? widget.labName,
            ),
          ),
          const SizedBox(height: 16),

          // Phone
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // WhatsApp
          TextField(
            controller: _whatsappController,
            decoration: const InputDecoration(
              labelText: 'رقم الواتساب',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Address
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('الكاميرا'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  List<Map<String, dynamic>> _getInfoItems() {
    final items = <Map<String, dynamic>>[];

    // Phone Number
    if (_labData!['phone'] != null) {
      items.add({
        'icon': Icons.phone,
        'title': 'رقم الهاتف',
        'content': _labData!['phone']?.toString() ?? 'غير محدد',
        'onTap': () => _launchPhone(_labData!['phone']),
        'isClickable': true,
      });
    }

    // WhatsApp Number - Always show with default number
    items.add({
      'icon': Icons.chat,
      'title': 'رقم الواتساب',
      'content': _labData!['whatsapp']?.toString() ?? '0991961111',
      'onTap': () => _launchWhatsApp(_labData!['whatsapp'] ?? '0991961111'),
      'isClickable': true,
    });

    // Address
    if (_labData!['address'] != null) {
      items.add({
        'icon': Icons.location_on,
        'title': 'العنوان',
        'content': _labData!['address']?.toString() ?? 'غير محدد',
        'onTap': null,
        'isClickable': false,
      });
    }

    return items;
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String content,
    VoidCallback? onTap,
    bool isClickable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 2),
                if (isClickable && onTap != null)
                  GestureDetector(
                    onTap: onTap,
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.black,
                      ),
                    ),
                  )
                else
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
