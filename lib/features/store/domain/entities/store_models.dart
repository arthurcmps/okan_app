class StoreUserState {
  const StoreUserState({
    required this.id,
    required this.email,
    required this.purchasedTemplateIds,
    required this.tags,
  });

  final String id;
  final String email;
  final List<String> purchasedTemplateIds;
  final List<String> tags;
}

class StoreExercise {
  const StoreExercise({
    required this.id,
    required this.name,
    required this.group,
    this.videoUrl,
  });

  final String id;
  final String name;
  final String group;
  final String? videoUrl;

  Map<String, dynamic> toExerciseMap() => {
        'nome': name,
        'grupo': group,
        'videoUrl': videoUrl,
      };
}

class StoreTemplate {
  const StoreTemplate({
    required this.id,
    required this.name,
    required this.price,
    required this.isPremium,
    required this.tags,
    required this.sheets,
    required this.legacyExercises,
    this.personalId,
    this.createdAt,
  });

  final String id;
  final String name;
  final double price;
  final bool isPremium;
  final String? personalId;
  final List<String> tags;
  final Map<String, List<Map<String, dynamic>>> sheets;
  final List<Map<String, dynamic>> legacyExercises;
  final DateTime? createdAt;

  Map<String, dynamic> get compatibleData => {
        'nome': name,
        'preco': price,
        'isPremium': isPremium,
        'personalId': personalId,
        'tags': tags,
        'fichas': sheets,
        'exercicios': legacyExercises,
      };
}

class PixPaymentData {
  const PixPaymentData({required this.qrCodeBase64, required this.copyPasteCode});

  final String qrCodeBase64;
  final String copyPasteCode;
}

class CardPaymentRequest {
  const CardPaymentRequest({
    required this.templateId,
    required this.cardNumber,
    required this.expirationMonth,
    required this.expirationYear,
    required this.securityCode,
    required this.cardholderName,
    required this.documentNumber,
    required this.payerEmail,
  });

  final String templateId;
  final String cardNumber;
  final int expirationMonth;
  final int expirationYear;
  final String securityCode;
  final String cardholderName;
  final String documentNumber;
  final String payerEmail;
}

class CardPaymentResult {
  const CardPaymentResult({required this.status, this.statusDetail});

  final String status;
  final String? statusDetail;

  bool get approved => status == 'approved';
}
