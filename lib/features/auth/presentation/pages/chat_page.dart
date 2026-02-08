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
  late String _chatId;
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _chatId = _gerarChatId(_currentUserId, widget.otherUserId);
  }

  // Gera um ID único para a conversa (sempre na ordem alfabética dos IDs)
  String _gerarChatId(String id1, String id2) {
    return id1.hashCode <= id2.hashCode ? '${id1}_$id2' : '${id2}_$id1';
  }

  void _enviarMensagem() async {
    if (_messageController.text.trim().isEmpty) return;

    final msg = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add({
      'senderId': _currentUserId,
      'text': msg,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Atualiza metadados do chat (para listar conversas recentes se precisar no futuro)
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'users': [_currentUserId, widget.otherUserId],
      'lastMessage': msg,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Rola para o fim
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Porque a lista é invertida (reverse: true)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0, // Remove o espaço extra do botão de voltar
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
          builder: (context, snapshot) {
            String photoUrl = "";
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              photoUrl = data['photoUrl'] ?? "";
            }

            return Row(
              children: [
                // FOTO DA OUTRA PESSOA
                CircleAvatar(
                  radius: 18,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  backgroundColor: Colors.grey[300],
                  child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 10),
                // NOME DA PESSOA
                Expanded(
                  child: Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Começa de baixo pra cima
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.circular(0),
                            bottomRight: isMe ? Radius.circular(0) : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['text'],
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Digite sua mensagem...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  radius: 24,
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