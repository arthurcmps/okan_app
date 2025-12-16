import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String role; // professor ou aluno [cite: 31]
  final String? photoUrl;
  final String age;
  final double weight;
  final String objectives;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
    required this.age,
    required this.weight,
    required this.objectives,
    required this.createdAt,
  });

  // Converte um documento Firestore em um UserModel (JSON para Objeto)
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId){
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      role: map['role'] ?? 'aluno',
      photoUrl: map['photoUrl'],
      age: map['age'] ?.toInt() ?? '',
      weight: (map['weight'] ?? 0).toDouble(),
      objectives: map['objectives'] ?? '',
      // O Firebase retorna Timestamp, precisamos converter para DateTime
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  // Converte um UserModel em um mapa para salvar no Firestore (Objeto para JSON)
  Map<String, dynamic> toMap(){
    return {
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
      'age': age,
      'weight': weight,
      'objectives': objectives,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}