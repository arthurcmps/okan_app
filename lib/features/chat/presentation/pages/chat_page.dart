import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/okan_async_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/repositories/firebase_chat_repository.dart';
import '../../domain/chat_id.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.repository,
    this.currentUserId,
  });

  final String otherUserId;
  final String otherUserName;
  final ChatRepository? repository;
  final String? currentUserId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final ChatRepository _chatRepository;
  late final String _chatId;
  late final String _currentUserId;
  late final Stream<String?> _otherUserPhotoStream;
  late Stream<List<ChatMessage>> _messagesStream;

  String _currentUserName = 'Usuário';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatRepository = widget.repository ?? FirebaseChatRepository();

    final currentUserId = widget.currentUserId ?? _chatRepository.currentUserId;
    if (currentUserId == null) {
      throw StateError('ChatPage requer um usuário autenticado.');
    }

    _currentUserId = currentUserId;
    _chatId = buildDeterministicChatId(_currentUserId, widget.otherUserId);
    _otherUserPhotoStream = _chatRepository.watchUserPhotoUrl(
      widget.otherUserId,
    );
    _messagesStream = _chatRepository.watchMessages(_chatId);
    _carregarNomeUsuarioAtual();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarNomeUsuarioAtual() async {
    try {
      final name = await _chatRepository.loadUserDisplayName(_currentUserId);
      if (!mounted) return;
      setState(() => _currentUserName = name);
    } catch (error) {
      debugPrint('ChatPage/loadUserDisplayName: ${error.runtimeType}');
    }
  }

  void _retryMessages() {
    setState(() {
      _messagesStream = _chatRepository.watchMessages(_chatId);
    });
  }

  Future<void> _enviarMensagem() async {
    if (_isSending) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await _chatRepository.sendMessage(
        chatId: _chatId,
        currentUserId: _currentUserId,
        otherUserId: widget.otherUserId,
        currentUserName: _currentUserName,
        text: message,
      );

      if (!mounted) return;
      _messageController.clear();

      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      debugPrint('ChatPage/sendMessage: ${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível enviar a mensagem. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: StreamBuilder<String?>(
          stream: _otherUserPhotoStream,
          builder: (context, snapshot) {
            final photoUrl = snapshot.data ?? '';
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
                    style: const TextStyle(
                      fontSize: 16,
                      overflow: TextOverflow.ellipsis,
                      fontWeight: FontWeight.bold,
                    ),
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
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const OkanLoadingState(
                    label: 'Carregando conversa',
                  );
                }

                if (snapshot.hasError) {
                  return OkanMessageState(
                    key: const ValueKey('chat-messages-error'),
                    icon: Icons.cloud_off_outlined,
                    title: 'Não foi possível carregar a conversa',
                    description:
                        'Verifique sua conexão e tente novamente em alguns instantes.',
                    actionLabel: 'Tentar novamente',
                    onAction: _retryMessages,
                    isError: true,
                    announce: true,
                  );
                }

                final messages = snapshot.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  return const OkanMessageState(
                    key: ValueKey('chat-messages-empty'),
                    icon: Icons.chat_bubble_outline,
                    title: 'Nenhuma mensagem ainda',
                    description:
                        'Envie uma mensagem para iniciar esta conversa.',
                  );
                }

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 20,
                  ),
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.secondary : AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight:
                                isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: isMe ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight:
                                isMe ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _isSending ? null : (_) => _enviarMensagem(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isSending
                      ? AppColors.primary.withOpacity(0.6)
                      : AppColors.primary,
                  radius: 24,
                  child: IconButton(
                    key: const ValueKey('chat-send-message'),
                    tooltip: 'Enviar mensagem',
                    icon: _isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.black,
                            size: 20,
                          ),
                    onPressed: _isSending ? null : _enviarMensagem,
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
