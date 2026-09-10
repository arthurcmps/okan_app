import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/okan_async_state.dart';
import '../widgets/auth_ui.dart';

class PersonalDataValue {
  const PersonalDataValue({this.gender, this.birthDate});

  final String? gender;
  final DateTime? birthDate;
}

typedef PersonalDataLoader = Future<PersonalDataValue> Function(String uid);
typedef PersonalDataSaver =
    Future<void> Function(String uid, PersonalDataValue value);
typedef PasswordUpdater = Future<void> Function(String password);

class PersonalDataPage extends StatefulWidget {
  const PersonalDataPage({
    super.key,
    required this.uid,
    this.loadData,
    this.saveData,
    this.updatePassword,
  });

  final String uid;
  final PersonalDataLoader? loadData;
  final PersonalDataSaver? saveData;
  final PasswordUpdater? updatePassword;

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  static const _genderOptions = <String>[
    'Mulher Cis',
    'Mulher Trans',
    'Homem Cis',
    'Homem Trans',
    'Não-Binário',
    'Outro',
  ];

  String? _selectedGender;
  DateTime? _birthDate;
  bool _isInitialLoading = true;
  bool _hasLoadError = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<PersonalDataValue> _loadFromFirebase(String uid) async {
    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = document.data();
    final birthDate = data?['birthDate'];

    return PersonalDataValue(
      gender: data?['gender'] as String?,
      birthDate: birthDate is Timestamp ? birthDate.toDate() : null,
    );
  }

  Future<void> _saveToFirebase(String uid, PersonalDataValue value) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'gender': value.gender,
      'birthDate': value.birthDate,
    });
  }

  Future<void> _updatePasswordInFirebase(String password) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw StateError('No authenticated user.');
    }
    await currentUser.updatePassword(password);
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isInitialLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      final value = await (widget.loadData ?? _loadFromFirebase)(widget.uid);
      if (!mounted) return;

      setState(() {
        _selectedGender = value.gender;
        _birthDate = value.birthDate;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitialLoading = false;
        _hasLoadError = true;
      });
    }
  }

  Future<void> _saveGeneralData() async {
    setState(() => _isSaving = true);

    try {
      await (widget.saveData ?? _saveToFirebase)(
        widget.uid,
        PersonalDataValue(
          gender: _selectedGender,
          birthDate: _birthDate,
        ),
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados atualizados com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar suas informações. Tente novamente.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    var passwordVisible = false;
    var confirmationVisible = false;
    var isUpdating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
          title: const Text(
            'Alterar senha',
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digite sua nova senha abaixo:',
                  style: TextStyle(color: AppColors.textSub),
                ),
                const SizedBox(height: 20),
                AuthPasswordField(
                  controller: passwordController,
                  label: 'Nova senha',
                  passwordVisible: passwordVisible,
                  textInputAction: TextInputAction.next,
                  onToggleVisibility: () => setDialogState(
                    () => passwordVisible = !passwordVisible,
                  ),
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: confirmationController,
                  label: 'Confirmar senha',
                  passwordVisible: confirmationVisible,
                  onToggleVisibility: () => setDialogState(
                    () => confirmationVisible = !confirmationVisible,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUpdating
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isUpdating
                  ? null
                  : () async {
                      final password = passwordController.text;
                      if (password != confirmationController.text) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('As senhas não coincidem.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      if (password.length < 6) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'A senha deve ter no mínimo 6 caracteres.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isUpdating = true);
                      try {
                        await (widget.updatePassword ??
                            _updatePasswordInFirebase)(password.trim());
                        if (!mounted || !dialogContext.mounted) return;

                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Senha alterada!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } on FirebaseAuthException catch (error) {
                        if (!mounted || !dialogContext.mounted) return;

                        if (error.code == 'requires-recent-login') {
                          Navigator.pop(dialogContext);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Por segurança, saia e entre novamente para '
                                'trocar a senha.',
                              ),
                              backgroundColor: AppColors.warning,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Não foi possível alterar a senha. '
                                'Tente novamente.',
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } catch (_) {
                        if (!mounted || !dialogContext.mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Não foi possível alterar a senha. '
                              'Tente novamente.',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => isUpdating = false);
                        }
                      }
                    },
              child: isUpdating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    confirmationController.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.black,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Informações pessoais',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textMain,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const OkanLoadingState(
        label: 'Carregando informações pessoais',
      );
    }

    if (_hasLoadError) {
      return OkanMessageState(
        icon: Icons.person_off_outlined,
        title: 'Não foi possível carregar suas informações',
        description: 'Confira sua conexão e tente novamente.',
        actionLabel: 'Tentar novamente',
        onAction: _loadData,
        isError: true,
        announce: true,
      );
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionTitle('Data de nascimento'),
          Semantics(
            button: true,
            label: _birthDate == null
                ? 'Selecionar data de nascimento'
                : 'Alterar data de nascimento, '
                      '${DateFormat('dd/MM/yyyy').format(_birthDate!)}',
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _birthDate == null
                            ? 'Toque para selecionar'
                            : DateFormat('dd/MM/yyyy').format(_birthDate!),
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Identidade de gênero'),
          DropdownButtonFormField<String>(
            value: _selectedGender,
            dropdownColor: AppColors.surface,
            style: const TextStyle(color: AppColors.textMain),
            decoration: const InputDecoration(
              prefixIcon: Icon(
                Icons.person_outline,
                color: AppColors.secondary,
              ),
              filled: true,
              fillColor: AppColors.surface,
            ),
            hint: const Text(
              'Selecione (opcional)',
              style: TextStyle(color: AppColors.textSub),
            ),
            items: _genderOptions
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedGender = value),
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: _isSaving ? null : _saveGeneralData,
            child: _isSaving
                ? const Semantics(
                    label: 'Salvando informações pessoais',
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : const Text('SALVAR ALTERAÇÕES'),
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.lock_reset),
            label: const Text('Alterar minha senha'),
            onPressed: _showChangePasswordDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.secondary,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
