class ArenaProfile {
  const ArenaProfile({
    required this.id,
    required this.name,
    this.email,
    this.photoUrl,
    this.weight = 0,
    this.bodyFatPercentage = 0,
  });

  final String id;
  final String name;
  final String? email;
  final String? photoUrl;
  final double weight;
  final double bodyFatPercentage;
}

class ArenaFriendCandidate {
  const ArenaFriendCandidate({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? photoUrl;
}

class ArenaFriendship {
  const ArenaFriendship({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
}

class ArenaFriendRequest {
  const ArenaFriendRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    this.requesterPhoto,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterPhoto;
}

class ArenaParticipant {
  const ArenaParticipant({
    required this.userId,
    required this.name,
    required this.status,
    this.photoUrl,
    this.startValue = 0,
  });

  final String userId;
  final String name;
  final String status;
  final String? photoUrl;
  final double startValue;
}

class ArenaChallenge {
  const ArenaChallenge({
    required this.id,
    required this.creatorId,
    required this.metric,
    required this.durationDays,
    required this.startDate,
    required this.participants,
    required this.imagesDeleted,
  });

  final String id;
  final String creatorId;
  final String metric;
  final int durationDays;
  final DateTime startDate;
  final Map<String, ArenaParticipant> participants;
  final bool imagesDeleted;

  DateTime get endDate => startDate.add(Duration(days: durationDays));
  bool get isEnded => DateTime.now().isAfter(endDate);
}

class ArenaRankingEntry {
  const ArenaRankingEntry({
    required this.userId,
    required this.name,
    required this.delta,
    this.photoUrl,
  });

  final String userId;
  final String name;
  final String? photoUrl;
  final double delta;
}

class ArenaPost {
  const ArenaPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.reactions,
    required this.commentsCount,
    this.authorPhoto,
    this.imageUrl,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final Map<String, List<String>> reactions;
  final int commentsCount;
}

class ArenaComment {
  const ArenaComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorPhoto,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String text;
  final DateTime createdAt;
}
