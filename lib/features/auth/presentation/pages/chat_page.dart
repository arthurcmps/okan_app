import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart'; // Importe suas cores

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

    // Atualiza metadados do chat
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'users': [_currentUserId, widget.otherUserId],
      'lastMessage': msg,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Rola para o fim
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, 
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Fundo Roxo Escuro
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
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
                UserAvatar(
                  photoUrl: photoUrl, 
                  name: widget.otherUserName,
                  radius: 18,
                ),
                
                const SizedBox(width: 10),
                
                Expanded(
                  child: Text(
                    widget.otherUserName,
                    style: const TextStyle(fontSize: 16, overflow: TextOverflow.ellipsis, fontWeight: FontWeight.bold),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
                
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Começa de baixo pra cima
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _currentUserId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          // Minha Msg: Neon | Outra Msg: Card Escuro
                          color: isMe ? AppColors.secondary : AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.circular(0),
                            bottomRight: isMe ? Radius.circular(0) : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          data['text'],
                          style: TextStyle(
                            // Minha Msg: Texto Preto | Outra Msg: Texto Branco
                            color: isMe ? Colors.black : Colors.white,
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
          
          // --- ÁREA DE INPUT ---
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: AppColors.surface, // Fundo escuro para a barra
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, -2))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white), // TEXTO BRANCO
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Digite sua mensagem...",
                      hintStyle: const TextStyle(color: Colors.white54), // Hint visível
                      filled: true,
                      fillColor: Colors.black26, // Fundo do input mais escuro
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.secondary, // Botão Neon
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black, size: 20), // Ícone preto
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