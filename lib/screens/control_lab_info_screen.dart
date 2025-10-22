import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lab_to_lab_admin/screens/lab_price_list_screen.dart';

class ControlLabInfoScreen extends StatefulWidget {
  final String labId;
  final String labName;
  const ControlLabInfoScreen({super.key, required this.labId, required this.labName});

  @override
  State<ControlLabInfoScreen> createState() => _ControlLabInfoScreenState();
}

class _ControlLabInfoScreenState extends State<ControlLabInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whats = TextEditingController();
  final TextEditingController _order = TextEditingController();
  String _contractType = 'prepaid';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('labToLap').doc(widget.labId).get();
      final data = doc.data() ?? {};
      _name.text = data['name']?.toString() ?? widget.labName;
      _address.text = data['address']?.toString() ?? '';
      _phone.text = data['phone']?.toString() ?? '';
      _whats.text = data['whatsApp']?.toString() ?? '';
      _order.text = data['order']?.toString() ?? '';
      _contractType = data['contractType']?.toString() ?? 'prepaid';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await FirebaseFirestore.instance.collection('labToLap').doc(widget.labId).update({
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'phone': _phone.text.trim(),
        'whatsApp': _whats.text.trim(),
        'order': int.tryParse(_order.text.trim()),
        'contractType': _contractType,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ البيانات'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
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
            'بيانات المعمل - ${widget.labName}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'اسم المعمل', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل الاسم' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _whats,
                          decoration: const InputDecoration(labelText: 'واتساب', border: OutlineInputBorder()),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _order,
                          decoration: const InputDecoration(labelText: 'الترتيب', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        const Text('نوع التعاقد', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'prepaid',
                              groupValue: _contractType,
                              onChanged: (v) => setState(() => _contractType = v!),
                            ),
                            const Text('Prepaid'),
                            const SizedBox(width: 16),
                            Radio<String>(
                              value: 'postpaid',
                              groupValue: _contractType,
                              onChanged: (v) => setState(() => _contractType = v!),
                            ),
                            const Text('Postpaid'),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7), foregroundColor: Colors.white),
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}


