import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;   // ID da outra pessoa
  final String otherUserName; // Nome da outra pessoa
  final String studentId;     // <--- NOVO: Precisamos saber ID do ALUNO dessa conversa

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.studentId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatRoomId;
  late bool _souPersonal;

  @override
  void initState() {
    super.initState();
    final myId = FirebaseAuth.instance.currentUser!.uid;
    // Se meu ID não é o do aluno, então eu sou o personal
    _souPersonal = (myId != widget.studentId);
    
    _setupChatRoomId();
    _marcarComoLida(); // Quando abro a tela, zero as notificações
  }

  void _setupChatRoomId() {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final List<String> ids = [myId, widget.otherUserId];
    ids.sort(); 
    _chatRoomId = "${ids[0]}_${ids[1]}";
  }

  // Zera a bolinha vermelha quando abro o chat
  Future<void> _marcarComoLida() async {
    // Se sou Personal, zero o 'unreadByPersonal'. Se sou Aluno, zero 'unreadByStudent'.
    final campoParaZerar = _souPersonal ? 'unreadByPersonal' : 'unreadByStudent';
    
    await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
      campoParaZerar: false,
    });
  }

  Future<void> _enviarMensagem() async {
    if (_messageController.text.trim().isEmpty) return;

    final myUser = FirebaseAuth.instance.currentUser;
    final msg = _messageController.text.trim();
    _messageController.clear();

    try {
      // 1. Salva a mensagem no Chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .add({
        'senderId': myUser!.uid,
        'senderName': myUser.displayName ?? 'Usuário',
        'text': msg,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // 2. NOTIFICAÇÃO: Avisa o outro que tem mensagem nova
      // Se sou Personal enviando, marco 'unreadByStudent: true'
      // Se sou Aluno enviando, marco 'unreadByPersonal: true'
      final campoParaNotificar = _souPersonal ? 'unreadByStudent' : 'unreadByPersonal';

      await FirebaseFirestore.instance.collection('users').doc(widget.studentId).update({
        campoParaNotificar: true,
      });

      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      debugPrint("Erro ao enviar: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(radius: 16, backgroundColor: Colors.white, child: Text(widget.otherUserName[0].toUpperCase())),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.otherUserName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final msgs = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final data = msgs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == myId;
                    String hora = "";
                    if (data['timestamp'] != null) {
                      final dt = (data['timestamp'] as Timestamp).toDate();
                      hora = DateFormat('HH:mm').format(dt);
                    }
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(color: isMe ? Colors.teal.shade100 : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 2, offset: const Offset(1,1))]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(data['text'] ?? '', style: const TextStyle(fontSize: 16)), const SizedBox(height: 4), Text(hora, style: TextStyle(fontSize: 10, color: Colors.grey[600]))]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8), color: Colors.white,
            child: Row(children: [Expanded(child: TextField(controller: _messageController, decoration: InputDecoration(hintText: "Digite...", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)), onSubmitted: (_) => _enviarMensagem())), const SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.teal, child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _enviarMensagem))]),
          ),
        ],
      ),
    );
  }
}