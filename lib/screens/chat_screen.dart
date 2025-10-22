import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  final String labId;
  final String labName;
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.labId,
    required this.labName,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _inboxSub;
  String? _senderName;
  String? _receiverName;

  // جلب المحادثة كاملة من Firestore مع ترتيب حسب الوقت
  Stream<QuerySnapshot<Map<String, dynamic>>> get _chatStream {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: widget.labId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _playClickSound() async {
    try {
      // شغل صوت النقر من ملف الأصول
      await _audioPlayer.play(AssetSource('sounds/mouse-click-104737.mp3'));
    } catch (e) {
      // في حال حدوث خطأ في تشغيل الصوت، لا تفعل شيء
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserNames();
    // وسم الرسائل الواردة كمقروءة لتصفير البادج
    _inboxSub = FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: widget.receiverId)
        .where('receiverId', isEqualTo: widget.labId)
        .where('isRead', isEqualTo: false)
        .snapshots();
    _inboxSub!.listen((snap) async {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'isRead': true});
      }
      try {
        await batch.commit();
      } catch (_) {}
    });
  }

  Future<void> _loadUserNames() async {
    try {
      // جلب اسم المرسل - تحقق من نوع المستخدم
      final prefs = await SharedPreferences.getInstance();
      final userType = prefs.getString('userType');
      
      if (userType == 'controlUser') {
        // إذا كان كنترول، استخدم اسم الكنترول
        _senderName = prefs.getString('userName') ?? 'الكنترول';
      } else {
        // إذا كان معمل، استخدم اسم المستخدم الحالي
        _senderName = prefs.getString('userName') ?? widget.labName;
      }

      // جلب اسم المستقبل
      final receiverDoc = await FirebaseFirestore.instance
          .collection('labToLap')
          .doc(widget.receiverId)
          .get();
      if (receiverDoc.exists) {
        _receiverName = receiverDoc.data()?['name']?.toString() ?? widget.receiverName;
      } else {
        _receiverName = widget.receiverName;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      _senderName = widget.labName;
      _receiverName = widget.receiverName;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    await _playClickSound(); // شغل الصوت قبل إرسال الرسالة

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': widget.labId,
        'receiverId': widget.receiverId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'participants': [widget.labId, widget.receiverId],
        'isRead': false,
      });
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الإرسال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _receiverName ?? widget.receiverName,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 8),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('controlUsers')
                    .doc(widget.receiverId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data()!;
                    final isOnline = data['isOnline'] == true;
                    if (isOnline) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allMessages = snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    final senderId = data['senderId'];
                    final receiverId = data['receiverId'];

                    return (senderId == widget.labId &&
                            receiverId == widget.receiverId) ||
                        (senderId == widget.receiverId &&
                            receiverId == widget.labId);
                  }).toList();

                  if (allMessages.isEmpty) {
                    return const Center(child: Text('لا توجد رسائل حتى الآن.'));
                  }

                  return ListView.builder(
                    reverse: true,
                    itemCount: allMessages.length,
                    itemBuilder: (context, index) {
                      final msgData = allMessages[index].data();
                      final message = msgData['message']?.toString() ?? '';
                      final senderId = msgData['senderId']?.toString() ?? '';
                      final isMe = senderId == widget.labId;

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              // اسم المستخدم
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                child: Text(
                                  isMe ? (_senderName ?? widget.labName) : (_receiverName ?? widget.receiverName),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // الرسالة
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.deepPurple : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontSize: 16,
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
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'اكتب رسالة...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF673AB7)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
