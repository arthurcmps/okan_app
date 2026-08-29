import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/pages/chat_page.dart';
import '../../data/repositories/firebase_students_repository.dart';
import '../../domain/entities/pending_student_invite.dart';
import '../../domain/entities/student_relationship_exception.dart';
import '../../domain/entities/student_summary.dart';
import '../../domain/repositories/students_repository.dart';
import 'student_detail_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({
    super.key,
    this.repository,
    this.professionalId,
  });

  final StudentsRepository? repository;
  final String? professionalId;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();

  late final StudentsRepository _studentsRepository;
  late final String _personalId;
  late final TabController _tabController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final currentProfessionalId =
        widget.professionalId ?? FirebaseAuth.instance.currentUser?.uid;

    if (currentProfessionalId == null) {
      throw StateError('StudentsPage requer um professor autenticado.');
    }

    _personalId = currentProfessionalId;
    _studentsRepository = widget.repository ?? FirebaseStudentsRepository();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _mostrarErroDeAcao(
    Object error, {
    required String action,
    bool fecharDialogoAtual = false,
  }) {
    debugPrint('StudentsPage/$action: $error');

    if (!mounted) return;

    if (error is StudentRelationshipException) {
      if (error.isPlanLimit) {
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

      _mostrarSnack(error.message, isError: true);
      return;
    }

    _mostrarSnack(
      'Não foi possível $action agora. Tente novamente em instantes.',
      isError: true,
    );
  }

  Future<void> _enviarConvite() async {
    final emailInput = _emailController.text.trim().toLowerCase();
    if (emailInput.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final alunosCanonicos = await _studentsRepository
          .findCanonicalStudentsByEmail(emailInput);

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

      if (aluno.id == _personalId) {
        _mostrarSnack('Você não pode convidar a si mesmo.', isError: true);
        return;
      }

      if (aluno.professorId == _personalId) {
        _mostrarSnack(
          'Este aluno já está na sua lista de ativos.',
          isError: true,
        );
        return;
      }

      final result = await _studentsRepository.createStudentInvite(
        studentId: aluno.id,
      );

      if (result.alreadyPending) {
        _mostrarSnack(
          'Já existe um convite pendente para este aluno.',
          isError: true,
        );
        return;
      }

      if (mounted) {
        _mostrarSnack(
          'Convite enviado para ${_studentName(aluno)}! 🚀',
          isError: false,
        );
        Navigator.pop(context);
        _emailController.clear();
      }
    } catch (error) {
      _mostrarErroDeAcao(
        error,
        action: 'enviar o convite',
        fecharDialogoAtual: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removerAluno(String alunoId) async {
    try {
      await _studentsRepository.unlinkStudent(studentId: alunoId);

      if (mounted) {
        Navigator.pop(context);
        _mostrarSnack('Aluno desvinculado.', isError: false);
      }
    } catch (error) {
      _mostrarErroDeAcao(
        error,
        action: 'desvincular este aluno',
        fecharDialogoAtual: true,
      );
    }
  }

  Future<void> _cancelarConvite(String inviteId) async {
    try {
      await _studentsRepository.cancelStudentInvite(inviteId: inviteId);
      if (mounted) _mostrarSnack('Convite cancelado.');
    } catch (error) {
      _mostrarErroDeAcao(error, action: 'cancelar este convite');
    }
  }

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
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _enviarConvite,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
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
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
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
        title: Text(
          titulo,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          msg,
          style: const TextStyle(color: Colors.white70),
        ),
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

  String _studentName(StudentSummary student) {
    return student.name.isEmpty ? 'Aluno' : student.name;
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
        children: [
          _buildActiveStudentsList(),
          _buildPendingInvitesList(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Convidar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: _mostrarDialogoAdicionar,
      ),
    );
  }

  Widget _buildActiveStudentsList() {
    return StreamBuilder<bool>(
      stream: _studentsRepository.watchProfessionalPremium(_personalId),
      builder: (context, personalSnapshot) {
        if (personalSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }

        final isPremium = personalSnapshot.data ?? false;

        return StreamBuilder<List<StudentSummary>>(
          stream: _studentsRepository.watchActiveStudents(_personalId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

            final alunos = snapshot.data!;

            return ListView.builder(
              itemCount: alunos.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final aluno = alunos[index];
                final nome = _studentName(aluno);
                final email = aluno.email;
                final isBloqueado = !isPremium && index > 2;

                return Card(
                  color: isBloqueado
                      ? AppColors.background
                      : AppColors.surface,
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
                            photoUrl: aluno.photoUrl,
                            name: nome,
                            radius: 25,
                          ),
                    title: Text(
                      nome,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isBloqueado
                            ? Colors.white54
                            : Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      email,
                      style: TextStyle(
                        color: isBloqueado
                            ? Colors.white38
                            : Colors.white70,
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
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentDetailPage(
                            studentId: aluno.id,
                            studentName: nome,
                            studentEmail: email,
                            repository: _studentsRepository,
                          ),
                        ),
                      );
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
                                    otherUserId: aluno.id,
                                    otherUserName: nome,
                                  ),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () =>
                              _confirmarRemocao(aluno.id, nome),
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

  Widget _buildPendingInvitesList() {
    return StreamBuilder<List<PendingStudentInvite>>(
      stream: _studentsRepository.watchPendingInvites(_personalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum convite pendente.',
              style: TextStyle(color: Colors.white30),
            ),
          );
        }

        final invites = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invites.length,
          itemBuilder: (context, index) {
            final invite = invites[index];

            return Card(
              color: AppColors.surface.withOpacity(0.5),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(
                  Icons.mark_email_unread_outlined,
                  color: AppColors.secondary,
                ),
                title: Text(
                  invite.studentEmail,
                  style: const TextStyle(color: Colors.white70),
                ),
                subtitle: const Text(
                  'Aguardando aceitação...',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.error,
                  ),
                  onPressed: () => _cancelarConvite(invite.id),
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
