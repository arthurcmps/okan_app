import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:okan_app/features/arena/data/repositories/firebase_arena_repository.dart';
import 'package:okan_app/features/arena/domain/entities/arena_models.dart';

void main() {
  ArenaFriendship friendship({
    required String id,
    required String userId,
    String name = 'Atleta Sintético',
  }) {
    return ArenaFriendship(
      id: id,
      otherUserId: userId,
      otherUserName: name,
    );
  }

  test(
    'supports sequential listeners after the first one is cancelled',
    () async {
      var requestedListens = 0;
      var receivedListens = 0;
      var requestedCancels = 0;
      var receivedCancels = 0;
      final requested = StreamController<List<ArenaFriendship>>.broadcast(
        onListen: () => requestedListens++,
        onCancel: () => requestedCancels++,
      );
      final received = StreamController<List<ArenaFriendship>>.broadcast(
        onListen: () => receivedListens++,
        onCancel: () => receivedCancels++,
      );
      addTearDown(requested.close);
      addTearDown(received.close);

      final combined = combineArenaFriendshipStreams(
        requested: requested.stream,
        received: received.stream,
      );
      final firstEvents = <List<ArenaFriendship>>[];
      final firstSub = combined.listen(firstEvents.add);

      requested.add([friendship(id: 'sent-1', userId: 'friend-1')]);
      received.add(const <ArenaFriendship>[]);
      await pumpEventQueue();

      expect(firstEvents.single.single.otherUserId, 'friend-1');
      expect(requestedListens, 1);
      expect(receivedListens, 1);

      await firstSub.cancel();
      await pumpEventQueue();
      expect(requestedCancels, 1);
      expect(receivedCancels, 1);

      final secondEvents = <List<ArenaFriendship>>[];
      final secondSub = combined.listen(secondEvents.add);
      requested.add(const <ArenaFriendship>[]);
      received.add([friendship(id: 'received-1', userId: 'friend-2')]);
      await pumpEventQueue();

      expect(secondEvents.single.single.otherUserId, 'friend-2');
      expect(requestedListens, 2);
      expect(receivedListens, 2);

      await secondSub.cancel();
    },
  );

  test(
    'shares one pair of upstream listeners across simultaneous subscribers',
    () async {
      var requestedListens = 0;
      var receivedListens = 0;
      var requestedCancels = 0;
      var receivedCancels = 0;
      final requested = StreamController<List<ArenaFriendship>>.broadcast(
        onListen: () => requestedListens++,
        onCancel: () => requestedCancels++,
      );
      final received = StreamController<List<ArenaFriendship>>.broadcast(
        onListen: () => receivedListens++,
        onCancel: () => receivedCancels++,
      );
      addTearDown(requested.close);
      addTearDown(received.close);

      final combined = combineArenaFriendshipStreams(
        requested: requested.stream,
        received: received.stream,
      );
      final firstEvents = <List<ArenaFriendship>>[];
      final secondEvents = <List<ArenaFriendship>>[];
      final firstSub = combined.listen(firstEvents.add);
      final secondSub = combined.listen(secondEvents.add);

      requested.add([
        friendship(id: 'sent-1', userId: 'friend-1'),
      ]);
      received.add([
        friendship(id: 'received-1', userId: 'friend-2'),
      ]);
      await pumpEventQueue();

      expect(requestedListens, 1);
      expect(receivedListens, 1);
      expect(firstEvents.single.map((friend) => friend.otherUserId), [
        'friend-1',
        'friend-2',
      ]);
      expect(secondEvents.single.map((friend) => friend.otherUserId), [
        'friend-1',
        'friend-2',
      ]);

      await firstSub.cancel();
      await pumpEventQueue();
      expect(requestedCancels, 0);
      expect(receivedCancels, 0);

      await secondSub.cancel();
      await pumpEventQueue();
      expect(requestedCancels, 1);
      expect(receivedCancels, 1);
    },
  );
}
