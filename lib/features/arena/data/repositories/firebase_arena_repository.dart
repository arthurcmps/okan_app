import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/storage_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/arena_models.dart';
import '../../domain/repositories/arena_repository.dart';

class FirebaseArenaRepository implements ArenaRepository {
  FirebaseArenaRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    StorageService? storageService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storageService = storageService ?? StorageService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final StorageService _storageService;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  String get _requiredUid {
    final uid = currentUserId;
    if (uid == null) throw StateError('Arena requer usuário autenticado.');
    return uid;
  }

  @override
  Future<ArenaProfile> loadCurrentProfile() => _loadProfile(_requiredUid);

  Future<ArenaProfile> _loadProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    return ArenaProfile(
      id: uid,
      name: _string(data['name'] ?? data['nome'], fallback: 'Atleta'),
      email: _nullableString(data['email']),
      photoUrl: _nullableString(data['photoUrl']),
      weight: _number(data['peso']),
      bodyFatPercentage: _number(data['bodyFatPercentage']),
    );
  }

  @override
  Future<ArenaFriendCandidate?> findFriendCandidateByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalized)
        .get();

    final candidates = query.docs
        .map(UserModel.fromDocument)
        .where((user) => user.isCanonicalIdentity && user.isAlunoMember)
        .toList(growable: false);

    if (candidates.length > 1) {
      throw StateError(
        'Encontramos mais de uma identidade válida para esse e-mail.',
      );
    }
    if (candidates.isEmpty) return null;

    final found = candidates.single;
    return ArenaFriendCandidate(
      id: found.uid,
      name: found.name,
      email: found.email,
      photoUrl: found.photoUrl,
    );
  }

  @override
  Future<bool> hasFriendshipWith(String otherUserId) async {
    final uid = _requiredUid;
    final sent = await _firestore
        .collection('friendships')
        .where('requesterId', isEqualTo: uid)
        .where('receiverId', isEqualTo: otherUserId)
        .get();
    if (sent.docs.isNotEmpty) return true;

    final received = await _firestore
        .collection('friendships')
        .where('requesterId', isEqualTo: otherUserId)
        .where('receiverId', isEqualTo: uid)
        .get();
    return received.docs.isNotEmpty;
  }

  @override
  Future<void> sendFriendRequest(ArenaFriendCandidate candidate) async {
    final uid = _requiredUid;
    if (await hasFriendshipWith(candidate.id)) {
      throw StateError('Já existe amizade ou convite pendente.');
    }

    final me = await _loadProfile(uid);
    await _firestore.collection('friendships').add({
      'requesterId': uid,
      'requesterName': me.name,
      'requesterPhoto': me.photoUrl,
      'receiverId': candidate.id,
      'receiverName': candidate.name,
      'receiverPhoto': candidate.photoUrl,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await sendArenaNotification(
      targetUserId: candidate.id,
      title: 'Novo Convite na Arena 🤝',
      body: '${me.name} quer adicionar você como amigo!',
    );
  }

  @override
  Future<void> respondFriendRequest({
    required String requestId,
    required String requesterId,
    required bool accept,
  }) async {
    if (!accept) {
      await _firestore.collection('friendships').doc(requestId).delete();
      return;
    }

    await _firestore
        .collection('friendships')
        .doc(requestId)
        .update({'status': 'accepted'});
    final me = await loadCurrentProfile();
    await sendArenaNotification(
      targetUserId: requesterId,
      title: 'Convite Aceito! ⚔️',
      body: '${me.name} agora é seu amigo na Arena Okan.',
    );
  }

  @override
  Future<void> removeFriendship(String friendshipId) {
    return _firestore.collection('friendships').doc(friendshipId).delete();
  }

  @override
  Stream<List<ArenaFriendship>> watchFriends() {
    final uid = _requiredUid;
    return _firestore
        .collection('friendships')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snapshot) {
          final result = <ArenaFriendship>[];
          for (final document in snapshot.docs) {
            final data = document.data();
            final requesterId = _string(data['requesterId']);
            final receiverId = _string(data['receiverId']);
            if (requesterId != uid && receiverId != uid) continue;
            final meRequested = requesterId == uid;
            result.add(
              ArenaFriendship(
                id: document.id,
                otherUserId: meRequested ? receiverId : requesterId,
                otherUserName: _string(
                  meRequested ? data['receiverName'] : data['requesterName'],
                  fallback: 'Atleta',
                ),
                otherUserPhoto: _nullableString(
                  meRequested ? data['receiverPhoto'] : data['requesterPhoto'],
                ),
              ),
            );
          }
          return result;
        });
  }

  @override
  Stream<List<ArenaFriendRequest>> watchPendingFriendRequests() {
    final uid = _requiredUid;
    return _firestore
        .collection('friendships')
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => ArenaFriendRequest(
                  id: document.id,
                  requesterId: _string(document.data()['requesterId']),
                  requesterName: _string(
                    document.data()['requesterName'],
                    fallback: 'Atleta',
                  ),
                  requesterPhoto: _nullableString(
                    document.data()['requesterPhoto'],
                  ),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Stream<List<ArenaChallenge>> watchChallenges() {
    final uid = _requiredUid;
    return _firestore
        .collection('challenges')
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
          final result = snapshot.docs.map(_challengeFromDocument).toList();
          result.sort((a, b) => b.startDate.compareTo(a.startDate));
          return result;
        });
  }

  ArenaChallenge _challengeFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final rawParticipants = Map<String, dynamic>.from(
      data['participants'] as Map? ?? const <String, dynamic>{},
    );
    final participants = <String, ArenaParticipant>{};
    rawParticipants.forEach((uid, raw) {
      final map = Map<String, dynamic>.from(raw as Map? ?? const {});
      participants[uid] = ArenaParticipant(
        userId: uid,
        name: _string(map['name'], fallback: 'Atleta'),
        status: _string(map['status'], fallback: 'pending'),
        photoUrl: _nullableString(map['photoUrl']),
        startValue: _number(map['startValue']),
      );
    });

    return ArenaChallenge(
      id: document.id,
      creatorId: _string(data['creatorId']),
      metric: _string(data['metric'], fallback: 'constancy'),
      durationDays: _int(data['durationDays'], fallback: 30),
      startDate: _date(data['startDate']) ?? DateTime.now(),
      participants: participants,
      imagesDeleted: data['imagensApagadas'] == true,
    );
  }

  @override
  Future<void> leaveChallenge(String challengeId) {
    final uid = _requiredUid;
    return _firestore.collection('challenges').doc(challengeId).update({
      'participantIds': FieldValue.arrayRemove([uid]),
      'participants.$uid': FieldValue.delete(),
    });
  }

  @override
  Future<void> respondChallenge({
    required ArenaChallenge challenge,
    required bool accept,
  }) async {
    final uid = _requiredUid;
    if (!accept) {
      await leaveChallenge(challenge.id);
      return;
    }

    final me = await loadCurrentProfile();
    var startValue = 0.0;
    if (challenge.metric == 'weight') startValue = me.weight;
    if (challenge.metric == 'bodyFatPercentage') {
      startValue = me.bodyFatPercentage;
    }

    await _firestore.collection('challenges').doc(challenge.id).update({
      'participants.$uid.status': 'accepted',
      'participants.$uid.startValue': startValue,
    });

    await sendArenaNotification(
      targetUserId: challenge.creatorId,
      title: 'Novo Gladiador na Arena! ⚔️',
      body: '${me.name} acabou de aceitar o seu desafio.',
    );
  }

  @override
  Future<void> createChallenge({
    required String metric,
    required int durationDays,
    required List<ArenaFriendship> invitedFriends,
  }) async {
    final uid = _requiredUid;
    final me = await loadCurrentProfile();
    var startValue = 0.0;
    if (metric == 'weight') startValue = me.weight;
    if (metric == 'bodyFatPercentage') startValue = me.bodyFatPercentage;

    final participantIds = <String>[uid];
    final participants = <String, dynamic>{
      uid: {
        'name': me.name,
        'photoUrl': me.photoUrl,
        'status': 'accepted',
        'startValue': startValue,
      },
    };

    for (final friend in invitedFriends) {
      participantIds.add(friend.otherUserId);
      participants[friend.otherUserId] = {
        'name': friend.otherUserName,
        'photoUrl': friend.otherUserPhoto,
        'status': 'pending',
      };
    }

    await _firestore.collection('challenges').add({
      'creatorId': uid,
      'metric': metric,
      'durationDays': durationDays,
      'startDate': FieldValue.serverTimestamp(),
      'participantIds': participantIds,
      'participants': participants,
      'imagensApagadas': false,
    });

    final label = _metricLabel(metric);
    for (final friend in invitedFriends) {
      await sendArenaNotification(
        targetUserId: friend.otherUserId,
        title: 'Você foi desafiado! 🛡️',
        body: '${me.name} montou uma Arena de $label.',
      );
    }
  }

  @override
  Future<List<ArenaRankingEntry>> calculateRanking(
    ArenaChallenge challenge,
  ) async {
    final limit = DateTime.now().isBefore(challenge.endDate)
        ? DateTime.now()
        : challenge.endDate;
    final ranking = <ArenaRankingEntry>[];

    for (final participant in challenge.participants.values) {
      if (participant.status != 'accepted') continue;
      var delta = 0.0;

      if (challenge.metric == 'weight' ||
          challenge.metric == 'bodyFatPercentage') {
        final profile = await _loadProfile(participant.userId);
        final current = challenge.metric == 'weight'
            ? profile.weight
            : profile.bodyFatPercentage;
        delta = current - participant.startValue;
      } else {
        final history = await _firestore
            .collection('workout_history')
            .where('studentId', isEqualTo: participant.userId)
            .get();
        var sessions = 0;
        var volume = 0.0;
        for (final document in history.docs) {
          final performedAt = _date(document.data()['dataRealizacao']);
          if (performedAt == null ||
              !performedAt.isAfter(challenge.startDate) ||
              !performedAt.isBefore(limit)) {
            continue;
          }
          sessions++;
          if (challenge.metric == 'volume') {
            final exercises = document.data()['exercicios'] as List? ?? const [];
            for (final raw in exercises) {
              final map = Map<String, dynamic>.from(raw as Map? ?? const {});
              volume += double.tryParse(
                    map['carga']?.toString().replaceAll(',', '.') ?? '0',
                  ) ??
                  0;
            }
          }
        }
        delta = challenge.metric == 'constancy' ? sessions.toDouble() : volume;
      }

      ranking.add(
        ArenaRankingEntry(
          userId: participant.userId,
          name: participant.name,
          photoUrl: participant.photoUrl,
          delta: delta,
        ),
      );
    }

    if (challenge.metric == 'weight' ||
        challenge.metric == 'bodyFatPercentage') {
      ranking.sort((a, b) => a.delta.compareTo(b.delta));
    } else {
      ranking.sort((a, b) => b.delta.compareTo(a.delta));
    }
    return ranking;
  }

  @override
  Future<void> sendArenaNotification({
    required String targetUserId,
    required String title,
    required String body,
  }) async {
    if (targetUserId == _requiredUid) return;
    await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add({
          'type': 'arena',
          'title': title,
          'body': body,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<void> cleanupChallengeImages(ArenaChallenge challenge) async {
    if (challenge.imagesDeleted) return;
    await _storageService.limparImagensArena(challengeId: challenge.id);
    await _firestore
        .collection('challenges')
        .doc(challenge.id)
        .update({'imagensApagadas': true});
  }

  @override
  Stream<List<ArenaPost>> watchPosts(String challengeId) {
    return _firestore
        .collection('challenges')
        .doc(challengeId)
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            final data = document.data();
            final rawReactions = Map<String, dynamic>.from(
              data['reactions'] as Map? ?? const {},
            );
            final reactions = <String, List<String>>{};
            rawReactions.forEach((emoji, value) {
              reactions[emoji] = (value as List? ?? const [])
                  .map((item) => item.toString())
                  .toList(growable: false);
            });
            return ArenaPost(
              id: document.id,
              authorId: _string(data['authorId']),
              authorName: _string(data['authorName'], fallback: 'Atleta'),
              authorPhoto: _nullableString(data['authorPhoto']),
              text: _string(data['text']),
              imageUrl: _nullableString(data['imageUrl']),
              createdAt: _date(data['timestamp']) ?? DateTime.now(),
              reactions: reactions,
              commentsCount: _int(data['commentsCount']),
            );
          }).toList(growable: false),
        );
  }

  @override
  Future<void> createTextPost({
    required String challengeId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    final me = await loadCurrentProfile();
    await _addPost(
      challengeId: challengeId,
      me: me,
      text: normalized,
      imageUrl: null,
    );
  }

  @override
  Future<void> createPhotoPost({
    required String challengeId,
    required Uint8List bytes,
    required String text,
  }) async {
    final me = await loadCurrentProfile();
    final imageUrl = await _storageService.uploadImagemArena(
      challengeId: challengeId,
      bytes: bytes,
    );
    await _addPost(
      challengeId: challengeId,
      me: me,
      text: text.trim().isEmpty ? 'Tá pago na Arena! 🔥' : text.trim(),
      imageUrl: imageUrl,
    );
  }

  Future<void> _addPost({
    required String challengeId,
    required ArenaProfile me,
    required String text,
    required String? imageUrl,
  }) {
    return _firestore
        .collection('challenges')
        .doc(challengeId)
        .collection('posts')
        .add({
          'authorId': me.id,
          'authorName': me.name,
          'authorPhoto': me.photoUrl,
          'text': text,
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'reactions': <String, dynamic>{},
          'commentsCount': 0,
        });
  }

  @override
  Future<void> toggleReaction({
    required String challengeId,
    required String postId,
    required String emoji,
  }) async {
    final uid = _requiredUid;
    final ref = _firestore
        .collection('challenges')
        .doc(challengeId)
        .collection('posts')
        .doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final reactions = Map<String, dynamic>.from(
        snapshot.data()?['reactions'] as Map? ?? const {},
      );
      final ids = List<dynamic>.from(reactions[emoji] as List? ?? const []);
      ids.contains(uid) ? ids.remove(uid) : ids.add(uid);
      reactions[emoji] = ids;
      transaction.update(ref, {'reactions': reactions});
    });
  }

  @override
  Stream<List<ArenaComment>> watchComments({
    required String challengeId,
    required String postId,
  }) {
    return _firestore
        .collection('challenges')
        .doc(challengeId)
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => ArenaComment(
                  id: document.id,
                  authorId: _string(document.data()['authorId']),
                  authorName: _string(
                    document.data()['authorName'],
                    fallback: 'Atleta',
                  ),
                  authorPhoto: _nullableString(document.data()['authorPhoto']),
                  text: _string(document.data()['text']),
                  createdAt:
                      _date(document.data()['timestamp']) ?? DateTime.now(),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> addComment({
    required String challengeId,
    required String postId,
    required String text,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    final me = await loadCurrentProfile();
    final postRef = _firestore
        .collection('challenges')
        .doc(challengeId)
        .collection('posts')
        .doc(postId);
    final commentRef = postRef.collection('comments').doc();
    final batch = _firestore.batch();
    batch.set(commentRef, {
      'authorId': me.id,
      'authorName': me.name,
      'authorPhoto': me.photoUrl,
      'text': normalized,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(postRef, {'commentsCount': FieldValue.increment(1)});
    await batch.commit();
  }

  static String _metricLabel(String metric) {
    switch (metric) {
      case 'bodyFatPercentage':
        return '% de Gordura';
      case 'weight':
        return 'Perda de Peso';
      case 'constancy':
        return 'Frequência de Treinos';
      case 'volume':
        return 'Carga Total Movida';
      default:
        return 'Desafio';
    }
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static String? _nullableString(dynamic value) {
    final normalized = _string(value);
    return normalized.isEmpty ? null : normalized;
  }
}
