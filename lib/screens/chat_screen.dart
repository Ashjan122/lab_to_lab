import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
          title: Text(
            widget.receiverName,
            style: const TextStyle(color: Colors.white),
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
