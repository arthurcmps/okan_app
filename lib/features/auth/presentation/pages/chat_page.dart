import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String otherUserId;   // ID da outra pessoa (Personal ou Aluno)
  final String otherUserName; // Nome da outra pessoa

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _setupChatRoomId();
  }

  // Cria um ID único para a conversa (sempre igual para o par Aluno/Personal)
  void _setupChatRoomId() {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    // Ordena os IDs para que "A conversando com B" seja a mesma sala que "B conversando com A"
    final List<String> ids = [myId, widget.otherUserId];
    ids.sort(); 
    _chatRoomId = "${ids[0]}_${ids[1]}";
  }

  Future<void> _enviarMensagem() async {
    if (_messageController.text.trim().isEmpty) return;

    final myUser = FirebaseAuth.instance.currentUser;
    final msg = _messageController.text.trim();
    _messageController.clear();

    try {
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
      
      // Rola a tela para o final
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // 0 porque a lista é invertida (reverse: true)
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(widget.otherUserName[0].toUpperCase()),
            ),
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
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Mais recentes embaixo (na lista invertida)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final msgs = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Começa de baixo para cima (padrão de chat)
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final data = msgs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == myId;
                    final String text = data['text'] ?? '';
                    
                    // Formata hora (ex: 14:30)
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
                        decoration: BoxDecoration(
                          color: isMe ? Colors.teal.shade100 : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                          ),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 2, offset: const Offset(1,1))]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(text, style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(hora, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // CAMPO DE TEXTO
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Digite uma mensagem...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _enviarMensagem,
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