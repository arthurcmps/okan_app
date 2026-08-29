/// Builds the canonical Firestore document ID for a one-to-one chat.
///
/// Participant IDs are sorted lexicographically so both sides of the
/// conversation always resolve to the same persistent chat document.
String buildDeterministicChatId(String firstUserId, String secondUserId) {
  final participantIds = [firstUserId, secondUserId]..sort();
  return '${participantIds[0]}_${participantIds[1]}';
}
