import 'dart:typed_data';

import '../entities/arena_models.dart';

abstract interface class ArenaRepository {
  String? get currentUserId;
  String? get currentUserEmail;

  Future<ArenaProfile> loadCurrentProfile();
  Future<ArenaFriendCandidate?> findFriendCandidateByEmail(String email);
  Future<bool> hasFriendshipWith(String otherUserId);
  Future<void> sendFriendRequest(ArenaFriendCandidate candidate);
  Future<void> respondFriendRequest({
    required String requestId,
    required String requesterId,
    required bool accept,
  });
  Future<void> removeFriendship(String friendshipId);
  Stream<List<ArenaFriendship>> watchFriends();
  Stream<List<ArenaFriendRequest>> watchPendingFriendRequests();

  Stream<List<ArenaChallenge>> watchChallenges();
  Future<void> leaveChallenge(String challengeId);
  Future<void> respondChallenge({
    required ArenaChallenge challenge,
    required bool accept,
  });
  Future<void> createChallenge({
    required String metric,
    required int durationDays,
    required List<ArenaFriendship> invitedFriends,
  });
  Future<List<ArenaRankingEntry>> calculateRanking(ArenaChallenge challenge);
  Future<void> sendArenaNotification({
    required String targetUserId,
    required String title,
    required String body,
  });

  Future<void> cleanupChallengeImages(ArenaChallenge challenge);
  Stream<List<ArenaPost>> watchPosts(String challengeId);
  Future<void> createTextPost({
    required String challengeId,
    required String text,
  });
  Future<void> createPhotoPost({
    required String challengeId,
    required Uint8List bytes,
    required String text,
  });
  Future<void> toggleReaction({
    required String challengeId,
    required String postId,
    required String emoji,
  });
  Stream<List<ArenaComment>> watchComments({
    required String challengeId,
    required String postId,
  });
  Future<void> addComment({
    required String challengeId,
    required String postId,
    required String text,
  });
}
