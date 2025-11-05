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
  bool _isSending = false;

  // جلب المحادثة كاملة من Firestore مع ترتيب حسب الوقت
  Stream<QuerySnapshot<Map<String, dynamic>>> get _chatStream {
    return FirebaseFirestore.instance
        .collection('messages')
        .where('participants', arrayContains: widget.receiverId)
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
    _inboxSub =
        FirebaseFirestore.instance
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
      print('Loading user names...');
      print('Widget labId: ${widget.labId}');
      print('Widget receiverId: ${widget.receiverId}');
      print('Widget labName: ${widget.labName}');
      print('Widget receiverName: ${widget.receiverName}');

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
      final receiverDoc =
          await FirebaseFirestore.instance
              .collection('labToLap')
              .doc(widget.receiverId)
              .get();
      if (receiverDoc.exists) {
        _receiverName =
            receiverDoc.data()?['name']?.toString() ?? widget.receiverName;
      } else {
        _receiverName = widget.receiverName;
      }

      print('Loaded names: sender=$_senderName, receiver=$_receiverName');

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading user names: $e');
      _senderName = widget.labName;
      _receiverName = widget.receiverName;
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime messageTime;
    if (timestamp is Timestamp) {
      messageTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      messageTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      messageTime.year,
      messageTime.month,
      messageTime.day,
    );

    String dateText;
    if (messageDate == today) {
      dateText = 'اليوم';
    } else if (messageDate == yesterday) {
      dateText = 'أمس';
    } else {
      dateText = '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }

    final timeText =
        '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';

    return '$dateText $timeText';
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return; //  منع الإرسال الفارغ أو المتكرر

    setState(() => _isSending = true); //  قفل زر الإرسال مؤقتًا
    final currentText = text; // نخزنه مؤقتًا قبل مسح الحقل
    _messageController.clear(); //  مسح الحقل فور الضغط

    await _playClickSound(); // شغل الصوت

    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': widget.labId,
        'senderName': _senderName ?? widget.labName,
        'receiverId': widget.receiverId,
        'receiverName': _receiverName ?? widget.receiverName,
        'message': currentText,
        'timestamp': FieldValue.serverTimestamp(),
        'participants': [widget.labId, widget.receiverId],
        'isRead': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء الإرسال: $e'),
          backgroundColor: Colors.red,
        ),
      );
      //  في حالة الخطأ نعيد النص للحقل
      _messageController.text = currentText;
    } finally {
      if (mounted) setState(() => _isSending = false); //  فتح الزر بعد الإرسال
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
          titleSpacing: 0, // إزالة المسافة الافتراضية
          title: Padding(
            padding: const EdgeInsets.only(left: 8), // مسافة صغيرة من اليسار
            child: Row(
              children: [
                // صورة البروفايل على اليسار
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('controlUsers')
                          .doc(widget.receiverId)
                          .snapshots(),
                  builder: (context, controlSnapshot) {
                    // جلب صورة المعمل من labToLap
                    return StreamBuilder<
                      DocumentSnapshot<Map<String, dynamic>>
                    >(
                      stream:
                          FirebaseFirestore.instance
                              .collection('labToLap')
                              .doc(widget.receiverId)
                              .snapshots(),
                      builder: (context, labSnapshot) {
                        String? profileImageUrl;
                        bool isOnline = false;

                        // فحص controlUsers أولاً
                        if (controlSnapshot.hasData &&
                            controlSnapshot.data!.exists) {
                          final data = controlSnapshot.data!.data()!;
                          profileImageUrl = data['profileImageUrl']?.toString();
                          isOnline = data['isOnline'] == true;
                        }
                        // إذا لم توجد صورة في controlUsers، فحص labToLap
                        else if (labSnapshot.hasData &&
                            labSnapshot.data!.exists) {
                          final data = labSnapshot.data!.data()!;
                          profileImageUrl = data['imageUrl']?.toString();
                          isOnline = data['isOnline'] == true;
                        }

                        return Stack(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              backgroundImage:
                                  profileImageUrl != null &&
                                          profileImageUrl.isNotEmpty
                                      ? NetworkImage(profileImageUrl)
                                      : null,
                              child:
                                  profileImageUrl == null ||
                                          profileImageUrl.isEmpty
                                      ? Text(
                                        (_receiverName ?? widget.receiverName)
                                                .isNotEmpty
                                            ? (_receiverName ??
                                                    widget.receiverName)[0]
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      )
                                      : null,
                            ),
                            // مؤشر الحالة (أخضر إذا كان متصلاً)
                            if (isOnline)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _receiverName ?? widget.receiverName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('controlUsers')
                                .doc(widget.receiverId)
                                .snapshots(),
                        builder: (context, controlSnapshot) {
                          return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('labToLap')
                                    .doc(widget.receiverId)
                                    .snapshots(),
                            builder: (context, labSnapshot) {
                              bool isOnline = false;

                              // فحص controlUsers أولاً
                              if (controlSnapshot.hasData &&
                                  controlSnapshot.data!.exists) {
                                final data = controlSnapshot.data!.data()!;
                                isOnline = data['isOnline'] == true;
                              }
                              // إذا لم توجد في controlUsers، فحص labToLap
                              else if (labSnapshot.hasData &&
                                  labSnapshot.data!.exists) {
                                final data = labSnapshot.data!.data()!;
                                isOnline = data['isOnline'] == true;
                              }

                              return Text(
                                isOnline ? 'متصل الآن' : 'غير متصل',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8), // مسافة على اليمين للتوازن
              ],
            ),
          ),
          backgroundColor: const Color(0xFF673AB7),
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
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

                  final allMessages =
                      snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    final senderId = data['senderId'];
                    final receiverId = data['receiverId'];

                        print(
                          'Message: senderId=$senderId, receiverId=$receiverId',
                        );
                        print(
                          'Widget: labId=${widget.labId}, receiverId=${widget.receiverId}',
                        );

                        // البحث عن الرسائل بين المستخدم الحالي والمعمل المحدد
                        // widget.labId هو المعمل، widget.receiverId هو المعمل أيضاً (نفس الشيء)
                        // نحتاج للبحث عن الرسائل التي تحتوي على المعمل في أي من الحقلين
                        return (senderId == widget.labId ||
                            receiverId == widget.labId);
                  }).toList();

                  print('Total messages found: ${allMessages.length}');

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

                      // تحديد إذا كانت الرسالة من المستخدم الحالي
                      // نحتاج للتحقق من نوع المستخدم الحالي
                      bool isMe = false;
                      if (_senderName == 'sara' || _senderName == 'الكنترول') {
                        // إذا كان المستخدم الحالي كنترول، فالرسالة مني إذا كان senderId يبدأ بـ control_user
                        isMe = senderId.startsWith('control_user');
                      } else {
                        // إذا كان المستخدم الحالي معمل، فالرسالة مني إذا كان senderId هو labId
                        isMe = senderId == widget.labId;
                      }

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                            children: [
                              // اسم المستخدم
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Text(
                                  //  لو الرسالة ما فيها senderName نحدد الاسم حسب senderId
                                  (msgData['senderName']
                                              ?.toString()
                                              .isNotEmpty ??
                                          false)
                                      ? msgData['senderName'].toString()
                                      : (senderId == widget.labId
                                          ? widget.labName
                                          : widget.receiverName),
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
                                  color:
                                      isMe
                                          ? Colors.deepPurple
                                          : Colors.grey[300],
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
                              // تاريخ ووقت الرسالة
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                child: Text(
                                  _formatMessageTime(msgData['timestamp']),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w400,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
              child: Row(
                children: [
                  Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 150, //  حد أقصى للارتفاع (مثلاً 5-6 أسطر)
                        ),
                    child: TextField(
                      controller: _messageController,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 1,
                          maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة...',
                        border: OutlineInputBorder(),
                          ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      icon:
                          _isSending
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF673AB7),
                                ),
                              )
                              : const Icon(
                                Icons.send,
                                color: Color(0xFF673AB7),
                              ),
                      onPressed:
                          _isSending
                              ? null
                              : _sendMessage, // تعطيل الزر أثناء الإرسال
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
