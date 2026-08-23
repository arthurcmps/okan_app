import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  static const String _userPhotosPath = 'user_photos';
  static const String _arenaDuelsPath = 'arena_duels';

  Future<File?> selecionarImagem({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 70,
  }) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
    );

    if (image == null) {
      return null;
    }

    return File(image.path);
  }

  Future<String> uploadFotoPerfil(File imagem) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Usuário não autenticado.');
    }

    final ref = _storage.ref().child(_userPhotosPath).child('${user.uid}.jpg');

    await ref.putFile(imagem, SettableMetadata(contentType: 'image/jpeg'));

    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'photoUrl': url,
    });

    await user.updatePhotoURL(url);

    return url;
  }

  Future<String> uploadImagemArena({
    required String challengeId,
    required Uint8List bytes,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Usuário não autenticado.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${timestamp}_${user.uid}.jpg';

    final ref = _storage
        .ref()
        .child(_arenaDuelsPath)
        .child(challengeId)
        .child(fileName);

    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

    return ref.getDownloadURL();
  }

  Future<void> limparImagensArena({required String challengeId}) async {
    final ref = _storage.ref().child(_arenaDuelsPath).child(challengeId);

    final result = await ref.listAll();

    for (final item in result.items) {
      await item.delete();
    }
  }
}
