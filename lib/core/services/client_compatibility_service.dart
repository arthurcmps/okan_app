import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

abstract final class ClientCompatibilityInfo {
  static const int schemaVersion = 2;
  static const String appVersion = '1.0.1';
  static const int buildNumber = 9;
}

class ClientCompatibilityService {
  ClientCompatibilityService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> markCurrentClient() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('client_state')
        .doc('current');

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);

      final currentState = {
        'schemaVersion': ClientCompatibilityInfo.schemaVersion,
        'appVersion': ClientCompatibilityInfo.appVersion,
        'buildNumber': ClientCompatibilityInfo.buildNumber,
        'platform': _platformName(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      if (snapshot.exists) {
        transaction.update(ref, currentState);
        return;
      }

      transaction.set(ref, {
        ...currentState,
        'firstSeenAt': FieldValue.serverTimestamp(),
      });
    });
  }

  String _platformName() {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'unknown',
    };
  }
}
