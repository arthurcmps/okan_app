import '../entities/store_models.dart';

abstract interface class StoreRepository {
  String? get currentUserId;

  Future<StoreUserState> loadCurrentUser();
  Stream<StoreUserState> watchCurrentUser();
  Stream<List<StoreTemplate>> watchPremiumTemplates();

  Future<void> acquireFreeTemplate(String templateId);
  Future<PixPaymentData> createPixPayment(String templateId);
  Future<CardPaymentResult> createCardPayment(CardPaymentRequest request);

  Stream<List<StoreExercise>> watchExercises();
  Future<void> saveExercise({
    String? exerciseId,
    required String name,
    required String group,
    required String videoUrl,
  });
  Future<void> deleteExercise(String exerciseId);

  Stream<List<StoreTemplate>> watchCurrentProfessionalTemplates();
  Stream<List<StoreTemplate>> watchSystemTemplates();
  Future<void> saveProfessionalTemplate({
    String? templateId,
    required String name,
    required List<Map<String, dynamic>> exercises,
  });
  Future<void> saveSystemTemplate({
    String? templateId,
    required String name,
    required Map<String, List<Map<String, dynamic>>> sheets,
    required List<String> tags,
    required double price,
  });
  Future<void> deleteTemplate(String templateId);
}
