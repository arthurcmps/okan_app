import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/theme/app_colors.dart';
import 'student_detail_page.dart';
import 'chat_page.dart';
import '../../data/models/user_model.dart';
import '../../data/services/professional_relationships_service.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final ProfessionalRelationshipsService _relationships =
      ProfessionalRelationshipsService();
  bool _isLoading = false;
  late TabController _tabController;
  final String _personalId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _isPremiumValue(dynamic value) {
    if (value == true) return true;

    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }

    return false;
  }

  bool _isPermissionDenied(Object error) {
    return error is FirebaseException && error.code == 'permission-denied';
  }

  void _mostrarErroDeAcao(
    Object error, {
    required String action,
    bool fecharDialogoAtual = false,
  }) {
    debugPrint('StudentsPage/$action: $error');

    if (!mounted) return;

    if (isProfessionalRelationshipPlanLimit(error)) {
      if (fecharDialogoAtual && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _mostrarAlerta(
          'Limite do Plano Base',
          'Seu Plano Base permite até 3 alunos entre ativos e convites '
              'pendentes. Seus vínculos atuais permanecem seguros. '
              'Para adicionar novos alunos, reative o Premium.',
        );
      });

      return;
    }

    final callableMessage = professionalRelationshipErrorMessage(error);
    if (callableMessage !=
        'Não foi possível concluir esta ação agora. Tente novamente em instantes.') {
      _mostrarSnack(callableMessage, isError: true);
      return;
    }

    if (_isPermissionDenied(error)) {
      if (fecharDialogoAtual && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _mostrarAlerta(
          'Ação indisponível no plano atual',
          'Seu plano atual limita a gestão de alguns vínculos de alunos. '
              'Este vínculo continua salvo e nenhum dado foi perdido. '
              'Para voltar a gerenciar todos os alunos normalmente, '
              'reative o Premium.',
        );
      });

      return;
    }

    _mostrarSnack(
      'Não foi possível $action agora. Tente novamente em instantes.',
      isError: true,
    );
  }

  Query<Map<String, dynamic>> _activeStudentsQuery() {
    return FirebaseFirestore.instance
        .collection('users')
        .where(
          Filter.or(
            Filter('professorId', isEqualTo: _personalId),
            Filter('personalId', isEqualTo: _personalId),
          ),
        );
  }

  // O cliente localiza o aluno para UX. O backend valida limite, identidade,
  // duplicidade e persiste convite/notificação de forma transacional.
  Future<void> _enviarConvite() async {
    final emailInput = _emailController.text.trim().toLowerCase();
    if (emailInput.isEmpty) return;

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailInput)
          .get();

      final alunosCanonicos = querySnapshot.docs
          .map(UserModel.fromDocument)
          .where(
            (candidate) =>
                candidate.isCanonicalIdentity && candidate.isAlunoMember,
          )
          .toList();

      if (alunosCanonicos.isEmpty) {
        if (mounted) {
          _mostrarAlerta(
            'Não encontrado',
            "Não achamos nenhum aluno com o e-mail '$emailInput'.",
          );
        }
        return;
      }

      if (alunosCanonicos.length > 1) {
        if (mounted) {
          _mostrarAlerta(
            'Cadastro ambíguo',
            'Existe mais de uma identidade canônica para esse e-mail. '
                'O convite foi bloqueado por segurança.',
          );
        }
        return;
      }

      final aluno = alunosCanonicos.single;

      if (aluno.id == user.uid) {
        _mostrarSnack('Você não pode convidar a si mesmo.', isError: true);
        return;
      }

      if (aluno.professorId == user.uid) {
        _mostrarSnack(
          'Este aluno já está na sua lista de ativos.',
          isError: true,
        );
        return;
      }

      final result = await _relationships.createStudentInvite(
        studentId: aluno.id,
      );

      if (result['alreadyPending'] == true) {
        _mostrarSnack(
          'Já existe um convite pendente para este aluno.',
          isError: true,
        );
        return;
      }

      if (mounted) {
        _mostrarSnack('Convite enviado para ${aluno.name}! 🚀', isError: false);
        Navigator.pop(context);
        _emailController.clear();
      }
    } catch (e) {
      _mostrarErroDeAcao(
        e,
        action: 'enviar o convite',
        fecharDialogoAtual: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removerAluno(String alunoId) async {
    try {
      await _relationships.unlinkStudent(studentId: alunoId);

      if (mounted) {
        Navigator.pop(context);
        _mostrarSnack('Aluno desvinculado.', isError: false);
      }
    } catch (e) {
      _mostrarErroDeAcao(
        e,
        action: 'desvincular este aluno',
        fecharDialogoAtual: true,
      );
    }
  }

  Future<void> _cancelarConvite(String inviteId) async {
    try {
      await _relationships.cancelStudentInvite(inviteId: inviteId);
      if (mounted) _mostrarSnack('Convite cancelado.');
    } catch (e) {
      _mostrarErroDeAcao(e, action: 'cancelar este convite');
    }
  }

  // --- UI HELPER: DIÁLOGO DE ADICIONAR ---
  void _mostrarDialogoAdicionar() {
    _emailController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Convidar Aluno',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'O aluno receberá uma notificação para aceitar.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail do Aluno',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.secondary),
                ),
                prefixIcon: Icon(Icons.email, color: AppColors.secondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _enviarConvite,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Enviar',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmarRemocao(String alunoId, String nome) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Desvincular Aluno?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Tem certeza que deseja remover $nome?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => _removerAluno(alunoId),
            child: const Text(
              'Desvincular',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _mostrarAlerta(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(titulo, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Entendi',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Meus Alunos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        // --- ABAS ---
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Ativos'),
            Tab(text: 'Convites Pendentes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildActiveStudentsList(), _buildPendingInvitesList()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Convidar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: _mostrarDialogoAdicionar,
      ),
    );
  }

  // --- LISTA 1: ALUNOS ATIVOS (COM TRAVA DE DOWNGRADE CORRIGIDA) ---
  Widget _buildActiveStudentsList() {
    return StreamBuilder<DocumentSnapshot>(
      // 1º Stream: Fica a ouvir o status Premium do Personal
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_personalId)
          .snapshots(),
      builder: (context, personalSnapshot) {
        if (personalSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }

        final personalData =
            personalSnapshot.data?.data() as Map<String, dynamic>?;
        final isPremium = _isPremiumValue(personalData?['isPremium']);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // 2º Stream: relação canônica professorId + fallback personalId.
          stream: _activeStudentsQuery().snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 80,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum aluno ativo.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              );
            }

            final alunos = snapshot.data!.docs;

            return ListView.builder(
              itemCount: alunos.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final doc = alunos[index];
                final dados = doc.data();
                final String nome = dados['name'] ?? 'Aluno';
                final String email = dados['email'] ?? '';

                // REGRA DE DOWNGRADE: Se não for premium, bloqueia do 4º aluno em diante (índice > 2)
                final bool isBloqueado = !isPremium && index > 2;

                return Card(
                  color: isBloqueado ? AppColors.background : AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isBloqueado
                          ? Colors.amber.withOpacity(0.35)
                          : Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: isBloqueado
                        ? const CircleAvatar(
                            backgroundColor: Colors.black45,
                            child: Icon(
                              Icons.lock_outline,
                              color: Colors.amber,
                            ),
                          )
                        : UserAvatar(
                            photoUrl: dados['photoUrl'],
                            name: nome,
                            radius: 25,
                          ),
                    title: Text(
                      nome,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isBloqueado ? Colors.white54 : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(
                        color: isBloqueado ? Colors.white38 : Colors.white70,
                      ),
                    ),
                    onTap: () {
                      if (isBloqueado) {
                        _mostrarAlerta(
                          'Acesso limitado pelo Plano Base',
                          'Este aluno continua vinculado à sua conta e nenhum '
                              'dado foi perdido. O Plano Base permite gerenciar '
                              'até 3 alunos por vez. Para acessar todos os '
                              'vínculos novamente, reative o Premium.',
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentDetailPage(
                              studentId: doc.id,
                              studentName: nome,
                              studentEmail: email,
                            ),
                          ),
                        );
                      }
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isBloqueado)
                          IconButton(
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.primary,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    otherUserId: doc.id,
                                    otherUserName: nome,
                                  ),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          // Mantém disponível para o professor reduzir vínculos extras.
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () => _confirmarRemocao(doc.id, nome),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- LISTA 2: PENDENTES ---
  Widget _buildPendingInvitesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invites')
          .where('personalId', isEqualTo: _personalId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum convite pendente.',
              style: TextStyle(color: Colors.white30),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              color: AppColors.surface.withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.secondary,
                ),
                title: Text(
                  data['toStudentEmail'] ?? 'Email desconhecido',
                  style: const TextStyle(color: Colors.white70),
                ),
                subtitle: const Text(
                  'Aguardando aceitação...',
                  style: TextStyle(color: AppColors.secondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  onPressed: () => _cancelarConvite(doc.id),
                  tooltip: 'Cancelar Convite',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
