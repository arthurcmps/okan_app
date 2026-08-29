import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../config/app_environment.dart';

class FirebaseEnvironmentService {
  FirebaseEnvironmentService._();

  static const int authPort = 9099;
  static const int firestorePort = 8080;
  static const int functionsPort = 5001;
  static const int storagePort = 9199;

  static const String developmentProjectId = 'demo-okan-dev';

  static Future<void> initialize(OkanEnvironmentConfig environment) async {
    await Firebase.initializeApp(
      options: environment.isDevelopment
          ? _developmentOptionsForCurrentPlatform
          : DefaultFirebaseOptions.currentPlatform,
    );

    if (!environment.usesFirebaseEmulators) {
      return;
    }

    final host = environment.emulatorHost!;

    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseStorage.instance.useStorageEmulator(host, storagePort);

    FirebaseFunctions.instanceFor(region: 'us-central1').useFunctionsEmulator(
      host,
      functionsPort,
    );
    FirebaseFunctions.instanceFor(
      region: 'southamerica-east1',
    ).useFunctionsEmulator(host, functionsPort);
  }

  static FirebaseOptions get _developmentOptionsForCurrentPlatform {
    if (kIsWeb) {
      return _developmentWeb;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _developmentAndroid;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _developmentApple;
      case TargetPlatform.windows:
        return _developmentWeb;
      case TargetPlatform.linux:
        return _developmentWeb;
      default:
        return _developmentWeb;
    }
  }

  static const FirebaseOptions _developmentWeb = FirebaseOptions(
    apiKey: 'demo-okan-dev-api-key',
    appId: '1:123456789012:web:0000000000000000000000',
    messagingSenderId: '123456789012',
    projectId: developmentProjectId,
    authDomain: '$developmentProjectId.firebaseapp.com',
    storageBucket: '$developmentProjectId.appspot.com',
  );

  static const FirebaseOptions _developmentAndroid = FirebaseOptions(
    apiKey: 'demo-okan-dev-api-key',
    appId: '1:123456789012:android:0000000000000000000000',
    messagingSenderId: '123456789012',
    projectId: developmentProjectId,
    storageBucket: '$developmentProjectId.appspot.com',
  );

  static const FirebaseOptions _developmentApple = FirebaseOptions(
    apiKey: 'demo-okan-dev-api-key',
    appId: '1:123456789012:ios:0000000000000000000000',
    messagingSenderId: '123456789012',
    projectId: developmentProjectId,
    storageBucket: '$developmentProjectId.appspot.com',
    iosBundleId: 'com.example.okanApp',
  );
}
