import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/widgets/okan_async_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import 'anamnese_tab.dart';
import 'assessments_tab.dart';
import 'library_admin_page.dart';
import 'login_page.dart';
import 'workout_history_page.dart';
import 'personal_data_page.dart';
import 'super_admin_page.dart';
import 'professor_subscription_page.dart';
import 'package:intl/intl.dart';
import '../../data/models/user_model.dart';

typedef ProfileDataStream = Stream<Map<String, dynamic>?> Function(String uid);
typedef ProfileImagePicker = Future<File?> Function(ImageSource source);
typedef ProfilePhotoUploader = Future<void> Function(File image);
typedef ProfileBirthDateUpdater =
    Future<void> Function(String uid, DateTime birthDate);
typedef ProfileSignOut = Future<void> Function();

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.userId,
    this.profileDataStream,
    this.imagePicker,
    this.photoUploader,
    this.birthDateUpdater,
    this.signOut,
    this.anamneseBuilder,
    this.assessmentsBuilder,
  });

  final String? userId;
  final ProfileDataStream? profileDataStream;
  final ProfileImagePicker? imagePicker;
  final ProfilePhotoUploader? photoUploader;
  final ProfileBirthDateUpdater? birthDateUpdater;
  final ProfileSignOut? signOut;
  final WidgetBuilder? anamneseBuilder;
  final WidgetBuilder? assessmentsBuilder;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final String? _userId;
  Stream<Map<String, dynamic>?>? _profileStream;
  late TabController _tabController;
  bool _isUploading = false;

  int _adminTapCount = 0;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    _subscribeToProfile();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _subscribeToProfile() {
    final uid = _userId;
    if (uid == null) return;

    _profileStream = (widget.profileDataStream ?? _defaultProfileDataStream)(
      uid,
    );
  }

  Stream<Map<String, dynamic>?> _defaultProfileDataStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.exists ? snapshot.data() : null);
  }

  void _retryProfile() {
    setState(_subscribeToProfile);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Método auxiliar para formatar em dd/MM/yyyy
  String _formatarDataNascimento(dynamic dataNascimento) {
    if (dataNascimento == null) return "--/--/----";
    try {
      DateTime nascimento;
      if (dataNascimento is Timestamp) {
        nascimento = dataNascimento.toDate();
      } else if (dataNascimento is DateTime) {
        nascimento = dataNascimento;
      } else {
        return "--/--/----";
      }
      return DateFormat('dd/MM/yyyy').format(nascimento);
    } catch (_) {
      return "--/--/----";
    }
  }

  // Método atualizado para calcular a idade a partir do formato correto
  String _calcularIdade(dynamic dataNascimento) {
    if (dataNascimento == null) return "--";
    try {
      DateTime nascimento;
      if (dataNascimento is Timestamp) {
        nascimento = dataNascimento.toDate();
      } else if (dataNascimento is DateTime) {
        nascimento = dataNascimento;
      } else {
        return "--";
      }
      final hoje = DateTime.now();
      int idade = hoje.year - nascimento.year;
      if (hoje.month < nascimento.month ||
          (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
        idade--;
      }
      return "$idade anos (${DateFormat('dd/MM/yyyy').format(nascimento)})";
    } catch (_) {
      return "--";
    }
  }

  Future<void> _editarDataNascimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    try {
      await (widget.birthDateUpdater ?? _updateBirthDate)(_userId!, picked);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Data atualizada para ${DateFormat('dd/MM/yyyy').format(picked)}!",
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível atualizar a data. Tente novamente.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateBirthDate(String uid, DateTime birthDate) {
    return FirebaseFirestore.instance.collection('users').doc(uid).update({
      'birthDate': birthDate,
    });
  }

  void _mostrarOpcoesFoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.textMain,
                ),
                title: const Text(
                  'Escolher da Galeria',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: AppColors.textMain,
                ),
                title: const Text(
                  'Tirar Foto Agora',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _atualizarFoto(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _atualizarFoto(ImageSource source) async {
    try {
      final imagem = await (widget.imagePicker ?? _pickImage)(source);
      if (imagem == null) return;

      setState(() => _isUploading = true);

      await (widget.photoUploader ?? _uploadPhoto)(imagem);

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível atualizar a foto. Tente novamente.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<File?> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 50,
    );
    return pickedFile == null ? null : File(pickedFile.path);
  }

  Future<void> _uploadPhoto(File image) async {
    await StorageService().uploadFotoPerfil(image);
  }

  Future<void> _signOut() async {
    await AuthService().deslogar();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _userId;
    if (uid == null) {
      return const Scaffold(
        body: OkanMessageState(
          icon: Icons.lock_outline,
          title: 'Sessão encerrada',
          description: 'Entre novamente para acessar seu perfil.',
          isError: true,
          announce: true,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Meu Perfil",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white30,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: "Conta", icon: Icon(Icons.person_outline)),
            Tab(text: "Anamnese", icon: Icon(Icons.assignment_ind_outlined)),
            Tab(text: "Medidas", icon: Icon(Icons.show_chart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAccountTab(),
          (widget.anamneseBuilder ??
              (_) => AnamneseTab(studentId: uid, isEditable: true))(context),
          (widget.assessmentsBuilder ??
              (_) => AssessmentsTab(studentId: uid))(context),
        ],
      ),
    );
  }

  Widget _buildAccountTab() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OkanMessageState(
            icon: Icons.cloud_off_outlined,
            title: 'Não foi possível carregar seu perfil',
            description: 'Verifique sua conexão e tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: _retryProfile,
            isError: true,
            announce: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const OkanLoadingState(label: 'Carregando perfil');
        }

        final data = snapshot.data;
        if (data == null) {
          return OkanMessageState(
            icon: Icons.person_off_outlined,
            title: 'Perfil indisponível',
            description: 'Não encontramos seus dados de perfil.',
            actionLabel: 'Tentar novamente',
            onAction: _retryProfile,
            isError: true,
            announce: true,
          );
        }

        final profile = UserModel.fromMap(data, _userId!);

        final String nome = profile.name.isNotEmpty ? profile.name : "Usuário";

        final String email = profile.email;
        final String? photoUrl = profile.photoUrl;

        final dynamic birthDateRaw =
            data['birthDate'] ?? data['dataNascimento'];
        final String idade = _calcularIdade(birthDateRaw);
        final bool precisaData = (birthDateRaw == null);

        // Persona funcional do app, não RBAC.
        final bool isProfessor = profile.isProfessorMember;

        String roleLabel = "ALUNO";

        if (profile.isProfessor) {
          roleLabel = "PERSONAL TRAINER";
        } else if (profile.isSuperAdmin) {
          roleLabel = "SUPER ADMIN";
        } else if (profile.isGymAdmin) {
          roleLabel = "GESTOR";
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (precisaData)
                Semantics(
                  button: true,
                  label: 'Adicionar data de nascimento',
                  onTap: _editarDataNascimento,
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      onTap: _editarDataNascimento,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Cadastro incompleto! Toque para adicionar sua Data de Nascimento.",
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _adminTapCount++;
                            if (_adminTapCount >= 7) {
                              _adminTapCount = 0;

                              if (profile.isSuperAdmin) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SuperAdminPage(),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Acesso Negado."),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          child: UserAvatar(
                            photoUrl: photoUrl,
                            name: nome,
                            radius: 60,
                          ),
                        ),
                        if (_isUploading)
                          Positioned.fill(
                            child: Semantics(
                              liveRegion: true,
                              label: 'Atualizando foto do perfil',
                              child: const ExcludeSemantics(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Semantics(
                            button: true,
                            label: 'Alterar foto do perfil',
                            onTap: _mostrarOpcoesFoto,
                            child: ExcludeSemantics(
                              child: GestureDetector(
                                onTap: _mostrarOpcoesFoto,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.background,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    if (idade != "--")
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          idade,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(color: Colors.white60, height: 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Configurações",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              _buildMenuOption(
                icon: Icons.badge_outlined,
                color: AppColors.secondary,
                title: "Informações Pessoais",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PersonalDataPage(uid: _userId!),
                  ),
                ),
              ),

              _buildMenuOption(
                icon: Icons.history,
                color: Colors.white,
                title: "Histórico de Treinos",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutHistoryPage(
                      studentId: _userId!,
                      studentName: nome,
                    ),
                  ),
                ),
              ),

              // Recursos exclusivos da persona professor no mobile.
              if (isProfessor)
                _buildMenuOption(
                  icon: Icons.workspace_premium,
                  color: AppColors.primary,
                  title: "Assinatura e Planos",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfessorSubscriptionPage(),
                    ),
                  ),
                ),
              if (isProfessor || profile.isSuperAdmin)
                _buildMenuOption(
                  icon: profile.isSuperAdmin
                      ? Icons.admin_panel_settings
                      : Icons.library_books,
                  color: profile.isSuperAdmin
                      ? AppColors.primary
                      : Colors.white,
                  title: profile.isSuperAdmin
                      ? "Administrar Catálogo"
                      : "Gerenciar Biblioteca",
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LibraryAdminPage(
                        canManageExerciseCatalog: profile.isSuperAdmin,
                        catalogOnly:
                            profile.isSuperAdmin && !profile.isProfessorMember,
                      ),
                    ),
                  ),
                ),

              _buildMenuOption(
                icon: Icons.logout,
                color: AppColors.error,
                title: "Sair da Conta",
                isDestructive: true,
                onTap: () async {
                  await (widget.signOut ?? _signOut)();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? AppColors.error : Colors.white,
            fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.white30,
        ),
        onTap: onTap,
      ),
    );
  }
}
