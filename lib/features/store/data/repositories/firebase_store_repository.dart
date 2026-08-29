import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_environment.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';

class FirebaseStoreRepository implements StoreRepository {
  FirebaseStoreRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    http.Client? httpClient,
    OkanEnvironmentConfig? environment,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
       _httpClient = httpClient ?? http.Client(),
       _environment = environment ?? OkanEnvironmentConfig.current;

  static const _mercadoPagoPublicKey =
      'TEST-13b66d79-52ea-410d-9efb-57db088806b4';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final http.Client _httpClient;
  final OkanEnvironmentConfig _environment;

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  String get _requiredUid {
    final uid = currentUserId;
    if (uid == null) throw StateError('Store requer usuário autenticado.');
    return uid;
  }

  void _requireExternalPaymentsEnabled() {
    if (!_environment.enableExternalPayments) {
      throw StateError(
        'Pagamentos externos estão desativados no ambiente DEV.',
      );
    }
  }

  @override
  Future<StoreUserState> loadCurrentUser() async {
    final uid = _requiredUid;
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return _userState(uid, snapshot.data() ?? const <String, dynamic>{});
  }

  @override
  Stream<StoreUserState> watchCurrentUser() {
    final uid = _requiredUid;
    return _firestore.collection('users').doc(uid).snapshots().map(
          (snapshot) =>
              _userState(uid, snapshot.data() ?? const <String, dynamic>{}),
        );
  }

  StoreUserState _userState(String uid, Map<String, dynamic> data) {
    final tags = <String>[];
    if (data['check_hipertrofia'] == true) tags.add('Hipertrofia');
    if (data['check_emagrecimento'] == true) tags.add('Emagrecimento');
    if (data['check_condicionamento'] == true) tags.add('Condicionamento');
    if (data['check_iniciante'] == true) tags.add('Iniciante');
    if (data['check_intermediário'] == true) tags.add('Intermediário');
    if (data['check_avançado'] == true) tags.add('Avançado');
    if (data['check_casa'] == true) tags.add('Casa');
    if (data['check_academia'] == true) tags.add('Academia');

    return StoreUserState(
      id: uid,
      email: _string(data['email'], fallback: _auth.currentUser?.email ?? ''),
      purchasedTemplateIds: (data['purchased_templates'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      tags: tags,
    );
  }

  @override
  Stream<List<StoreTemplate>> watchPremiumTemplates() {
    return _firestore
        .collection('workout_templates')
        .where('isPremium', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => _template(document.id, document.data()))
              .toList(growable: false),
        );
  }

  @override
  Future<void> acquireFreeTemplate(String templateId) async {
    await _auth.currentUser?.getIdToken(true);
    final callable = _functions.httpsCallable('adquirirTemplateGratuito');
    await callable.call({'productId': 'workout_template:$templateId'});
  }

  @override
  Future<PixPaymentData> createPixPayment(String templateId) async {
    _requireExternalPaymentsEnabled();

    await _auth.currentUser?.getIdToken(true);
    final callable = _functions.httpsCallable('criarPagamentoPix');
    final result = await callable.call({
      'productId': 'workout_template:$templateId',
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return PixPaymentData(
      qrCodeBase64: _string(data['qr_code_base64']),
      copyPasteCode: _string(data['qr_code']),
    );
  }

  @override
  Future<CardPaymentResult> createCardPayment(CardPaymentRequest request) async {
    _requireExternalPaymentsEnabled();

    await _auth.currentUser?.getIdToken(true);

    final tokenUri = Uri.parse(
      'https://api.mercadopago.com/v1/card_tokens?public_key=$_mercadoPagoPublicKey',
    );
    final response = await _httpClient.post(
      tokenUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'card_number': request.cardNumber,
        'expiration_month': request.expirationMonth,
        'expiration_year': request.expirationYear,
        'security_code': request.securityCode,
        'cardholder': {
          'name': request.cardholderName,
          'identification': {
            'type': 'CPF',
            'number': request.documentNumber,
          },
        },
      }),
    );

    final tokenData = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final token = tokenData['id']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError(_mercadoPagoError(tokenData));
    }

    final paymentMethod = _paymentMethodFor(request.cardNumber);
    final callable = _functions.httpsCallable('criarPagamentoCartao');
    final result = await callable.call({
      'productId': 'workout_template:${request.templateId}',
      'tokenCartao': token,
      'parcelas': 1,
      'metodoPagamentoId': paymentMethod,
      'emailPagador': request.payerEmail.isEmpty
          ? 'email@teste.com'
          : request.payerEmail,
      'tipoDoc': 'CPF',
      'numeroDoc': request.documentNumber,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    return CardPaymentResult(
      status: _string(data['status']),
      statusDetail: _nullableString(data['status_detail']),
    );
  }

  @override
  Stream<List<StoreExercise>> watchExercises() {
    return _firestore.collection('exercises').orderBy('nome').snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (document) => StoreExercise(
                  id: document.id,
                  name: _string(document.data()['nome']),
                  group: _string(document.data()['grupo'], fallback: 'Geral'),
                  videoUrl: _nullableString(
                    document.data()['videoUrl'] ?? document.data()['video'],
                  ),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> saveExercise({
    String? exerciseId,
    required String name,
    required String group,
    required String videoUrl,
  }) async {
    final payload = <String, dynamic>{
      'nome': name.trim(),
      'grupo': group.trim(),
      'videoUrl': videoUrl.trim(),
      'criadoEm': FieldValue.serverTimestamp(),
    };
    if (exerciseId == null) {
      await _firestore.collection('exercises').add(payload);
    } else {
      await _firestore.collection('exercises').doc(exerciseId).update(payload);
    }
  }

  @override
  Future<void> deleteExercise(String exerciseId) {
    return _firestore.collection('exercises').doc(exerciseId).delete();
  }

  @override
  Stream<List<StoreTemplate>> watchCurrentProfessionalTemplates() {
    final uid = _requiredUid;
    return _firestore
        .collection('workout_templates')
        .where('personalId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final templates = snapshot.docs
              .map((document) => _template(document.id, document.data()))
              .toList();
          templates.sort((a, b) {
            final aDate = a.createdAt;
            final bDate = b.createdAt;
            if (aDate == null || bDate == null) return 0;
            return bDate.compareTo(aDate);
          });
          return templates;
        });
  }

  @override
  Stream<List<StoreTemplate>> watchSystemTemplates() {
    return _firestore
        .collection('workout_templates')
        .where('personalId', isEqualTo: 'SYSTEM_ADMIN')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => _template(document.id, document.data()))
              .toList(growable: false),
        );
  }

  @override
  Future<void> saveProfessionalTemplate({
    String? templateId,
    required String name,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final payload = <String, dynamic>{
      'personalId': _requiredUid,
      'nome': name.trim(),
      'exercicios': exercises,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (templateId == null) {
      await _firestore.collection('workout_templates').add(payload);
    } else {
      await _firestore
          .collection('workout_templates')
          .doc(templateId)
          .update(payload);
    }
  }

  @override
  Future<void> saveSystemTemplate({
    String? templateId,
    required String name,
    required Map<String, List<Map<String, dynamic>>> sheets,
    required List<String> tags,
    required double price,
  }) async {
    final payload = <String, dynamic>{
      'personalId': 'SYSTEM_ADMIN',
      'nome': name.trim(),
      'fichas': sheets,
      'exercicios': sheets['A'] ?? const <Map<String, dynamic>>[],
      'tags': tags,
      'preco': price,
      'isPremium': true,
      if (templateId == null) 'timestamp': FieldValue.serverTimestamp(),
    };
    if (templateId == null) {
      await _firestore.collection('workout_templates').add(payload);
    } else {
      await _firestore
          .collection('workout_templates')
          .doc(templateId)
          .update(payload);
    }
  }

  @override
  Future<void> deleteTemplate(String templateId) {
    return _firestore.collection('workout_templates').doc(templateId).delete();
  }

  StoreTemplate _template(String id, Map<String, dynamic> data) {
    final sheets = <String, List<Map<String, dynamic>>>{};
    final rawSheets = data['fichas'];
    if (rawSheets is Map) {
      rawSheets.forEach((key, value) {
        sheets[key.toString()] = (value as List? ?? const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      });
    }
    final legacyExercises = (data['exercicios'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    return StoreTemplate(
      id: id,
      name: _string(data['nome'], fallback: 'Sem Nome'),
      price: _number(data['preco']),
      isPremium: data['isPremium'] == true,
      personalId: _nullableString(data['personalId']),
      tags: (data['tags'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      sheets: sheets,
      legacyExercises: legacyExercises,
      createdAt: _date(data['timestamp']),
    );
  }

  static String _paymentMethodFor(String cardNumber) {
    if (cardNumber.startsWith('4')) return 'visa';
    if (cardNumber.startsWith('3')) return 'amex';
    if (cardNumber.startsWith('6')) return 'elo';
    return 'master';
  }

  static String _mercadoPagoError(Map<String, dynamic> data) {
    final causes = data['cause'];
    if (causes is List && causes.isNotEmpty && causes.first is Map) {
      final cause = Map<String, dynamic>.from(causes.first as Map);
      final code = cause['code']?.toString() ?? '';
      final fallback = cause['description']?.toString() ??
          'Dados inválidos. Verifique as informações.';
      switch (code) {
        case '205':
          return 'Digite o número do seu cartão.';
        case '208':
        case '209':
          return 'Mês ou ano de validade inválido.';
        case '212':
        case '213':
        case '214':
        case '322':
        case '323':
        case '324':
          return 'CPF inválido. Verifique os números.';
        case '221':
          return 'Digite o nome igual ao do cartão.';
        case '224':
          return 'Digite o CVV (código de segurança).';
        case 'E301':
          return 'Número do cartão inválido.';
        case 'E302':
          return 'CVV inválido. Verifique o código no verso.';
        case '316':
          return 'Nome do titular inválido.';
        case '325':
        case '326':
          return 'Data de validade incorreta ou expirada.';
        default:
          return fallback;
      }
    }
    return data['message']?.toString() ??
        'Dados inválidos. Verifique as informações.';
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  static String _string(dynamic value, {String fallback = ''}) {
    if (value is! String) return fallback;
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static String? _nullableString(dynamic value) {
    final valueString = _string(value);
    return valueString.isEmpty ? null : valueString;
  }
}
