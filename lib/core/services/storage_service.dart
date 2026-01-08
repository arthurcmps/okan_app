import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  // Função para selecionar imagem da Galeria
  Future<File?> selecionarImagem() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  // Função para fazer Upload e atualizar o Perfil
  Future<String?> uploadFotoPerfil(File imagem) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Define o caminho no Storage: profile_photos/USER_ID.jpg
      final ref = _storage.ref().child('profile_photos').child('${user.uid}.jpg');

      // 2. Faz o upload
      await ref.putFile(imagem);

      // 3. Pega a URL de download (link público da foto)
      final url = await ref.getDownloadURL();

      // 4. Atualiza o Auth (para aparecer user.photoURL)
      await user.updatePhotoURL(url);

      // 5. Atualiza o Firestore (para aparecer nos dados do usuário)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photoUrl': url,
      });

      return url;
    } catch (e) {
      print("Erro no upload: $e");
      return null;
    }
  }
}