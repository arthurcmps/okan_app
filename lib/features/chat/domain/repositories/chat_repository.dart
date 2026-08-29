import '../entities/chat_message.dart';

abstract interface class ChatRepository {
  Future<String> loadUserDisplayName(String userId);

  Stream<String?> watchUserPhotoUrl(String userId);

  Stream<List<ChatMessage>> watchMessages(String chatId);

  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String text,
  });
}
