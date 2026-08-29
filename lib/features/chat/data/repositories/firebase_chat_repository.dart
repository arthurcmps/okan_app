import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<String> loadUserDisplayName(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();

    if (data == null) return 'Usuário';

    return _stringOrFallback(data['name'] ?? data['nome'], 'Usuário');
  }

  @override
  Stream<String?> watchUserPhotoUrl(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (data == null) return null;

        final value = data['photoUrl'];
        if (value is! String) return null;

        final normalized = value.trim();
        return normalized.isEmpty ? null : normalized;
      },
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) {
                final data = document.data();
                return ChatMessage(
                  senderId: _stringOrFallback(data['senderId'], ''),
                  text: _stringOrFallback(data['text'], ''),
                );
              })
              .toList(growable: false),
        );
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String text,
  }) async {
    final normalizedMessage = text.trim();
    if (normalizedMessage.isEmpty) return;

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'text': normalizedMessage,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await _firestore.collection('chats').doc(chatId).set({
      'users': [currentUserId, otherUserId],
      'lastMessage': normalizedMessage,
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (currentUserId == otherUserId) return;

    await _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('notifications')
        .add({
          'type': 'message',
          'title': 'Nova mensagem de $currentUserName',
          'body': normalizedMessage,
          'senderName': currentUserName,
          'actionId': currentUserId,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  static String _stringOrFallback(dynamic value, String fallback) {
    if (value is! String) return fallback;
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}
