import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/repositories/firebase_arena_repository.dart';
import '../../domain/entities/arena_models.dart';
import '../../domain/repositories/arena_repository.dart';
import 'duel_room_page.dart';

String getNomeMetricaGlobal(String metric) {
  switch (metric) {
    case 'bodyFatPercentage':
      return '% de Gordura';
    case 'weight':
      return 'Perda de Peso';
    case 'constancy':
      return 'Frequência de Treinos';
    case 'volume':
      return 'Carga Total Movida';
    default:
      return 'Desafio';
  }
}

class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key, this.repository});

  final ArenaRepository? repository;

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage>
    with SingleTickerProviderStateMixin {
  late final ArenaRepository _repository;
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  ArenaFriendCandidate? _foundUser;
  bool _searching = false;

  String get _uid => _repository.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseArenaRepository();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchFriend() async {
    final email = _searchCtrl.text.trim().toLowerCase();
    if (email.isEmpty || email == _repository.currentUserEmail?.toLowerCase()) {
      return;
    }

    setState(() {
      _searching = true;
      _foundUser = null;
    });

    try {
      final found = await _repository.findFriendCandidateByEmail(email);
      if (!mounted) return;
      setState(() => _foundUser = found);
      if (found == null) {
        _showMessage('Nenhum atleta ativo encontrado com esse e-mail.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final candidate = _foundUser;
    if (candidate == null) return;
    try {
      await _repository.sendFriendRequest(candidate);
      if (!mounted) return;
      setState(() => _foundUser = null);
      _searchCtrl.clear();
      _showMessage(
        'Pedido de amizade enviado!',
        backgroundColor: AppColors.primary,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        error.toString().replaceFirst('Bad state: ', ''),
        backgroundColor: Colors.amber,
      );
    }
  }

  Future<void> _respondFriendRequest(
    ArenaFriendRequest request,
    bool accept,
  ) async {
    await _repository.respondFriendRequest(
      requestId: request.id,
      requesterId: request.requesterId,
      accept: accept,
    );
    if (mounted && accept) {
      _showMessage(
        'Amigo adicionado à Arena!',
        backgroundColor: AppColors.success,
      );
    }
  }

  void _confirmRemoveFriend(ArenaFriendship friendship) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Desfazer Amizade?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Tem certeza que deseja remover ${friendship.otherUserName} da sua lista de amigos?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _repository.removeFriendship(friendship.id);
              if (mounted) _showMessage('Amizade desfeita.');
            },
            child: const Text(
              'Remover Amigo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveChallenge(ArenaChallenge challenge) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Abandonar Duelo?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tem certeza que deseja sair desta batalha? Você será removido do ranking.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ficar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _repository.leaveChallenge(challenge.id);
              if (mounted) _showMessage('Você saiu do duelo com sucesso.');
            },
            child: const Text(
              'Abandonar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Arena Okan ⚔️',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepOrangeAccent,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.deepOrangeAccent,
          labelColor: Colors.deepOrangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Duelos'),
            Tab(text: 'Meus Amigos'),
            Tab(text: 'Buscar'),
            Tab(text: 'Convites'),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.deepOrangeAccent,
              icon: const Icon(Icons.add_moderator, color: Colors.white),
              label: const Text(
                'NOVO DUELO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _openCreateChallenge,
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChallengesTab(),
          _buildFriendsTab(),
          _buildSearchTab(),
          _buildInvitesTab(),
        ],
      ),
    );
  }

  Widget _buildChallengesTab() {
    return StreamBuilder<List<ArenaChallenge>>(
      stream: _repository.watchChallenges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepOrangeAccent),
          );
        }

        final challenges = snapshot.data!
            .where((challenge) =>
                challenge.participants[_uid]?.status == 'accepted')
            .toList(growable: false);

        if (challenges.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 16),
                Text(
                  'Nenhum duelo ativo.',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                Text(
                  "Clique em 'NOVO DUELO' para começar!",
                  style: TextStyle(color: Colors.white30, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            final accepted = challenge.participants.values
                .where((participant) => participant.status == 'accepted')
                .toList(growable: false);
            final names = accepted
                .map((participant) => participant.name.split(' ').first)
                .toList(growable: false);
            final remaining = challenge.isEnded
                ? 0
                : challenge.endDate.difference(DateTime.now()).inDays;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DuelRoomPage(
                    challenge: challenge,
                    repository: _repository,
                  ),
                ),
              ),
              child: Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: challenge.isEnded
                        ? Colors.amber.withOpacity(0.5)
                        : Colors.deepOrangeAccent.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              challenge.isEnded
                                  ? 'DUELO ENCERRADO 🏅'
                                  : 'Duelo de ${getNomeMetricaGlobal(challenge.metric)}',
                              style: TextStyle(
                                color: challenge.isEnded
                                    ? Colors.amber
                                    : Colors.deepOrangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!challenge.isEnded)
                            Text(
                              '$remaining dias',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.exit_to_app,
                              color: Colors.white30,
                            ),
                            onPressed: () => _confirmLeaveChallenge(challenge),
                          ),
                        ],
                      ),
                      Text(
                        'Arena: ${accepted.length} Atletas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        names.isEmpty ? 'Aguardando aceites...' : names.join(', '),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendsTab() {
    return StreamBuilder<List<ArenaFriendship>>(
      stream: _repository.watchFriends(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final friends = snapshot.data!;
        if (friends.isEmpty) {
          return const Center(
            child: Text(
              "Adicione amigos na aba 'Buscar' para desafiá-los!",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index];
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: UserAvatar(
                  photoUrl: friend.otherUserPhoto,
                  name: friend.otherUserName,
                  radius: 20,
                ),
                title: Text(
                  friend.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                  onPressed: () => _confirmRemoveFriend(friend),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Encontre um Atleta',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Digite o e-mail exato do usuário.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'email@exemplo.com',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _searching ? null : _searchFriend,
                icon: _searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (_foundUser case final candidate?)
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: UserAvatar(
                photoUrl: candidate.photoUrl,
                name: candidate.name,
                radius: 20,
              ),
              title: Text(
                candidate.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: _sendFriendRequest,
                child: const Text(
                  'Adicionar',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInvitesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Convites de Duelo ⚔️',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          _buildChallengeInvites(),
          const SizedBox(height: 30),
          const Text(
            'Pedidos de Amizade 🤝',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          _buildFriendInvites(),
        ],
      ),
    );
  }

  Widget _buildChallengeInvites() {
    return StreamBuilder<List<ArenaChallenge>>(
      stream: _repository.watchChallenges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final pending = snapshot.data!
            .where((challenge) => challenge.participants[_uid]?.status == 'pending')
            .toList(growable: false);
        if (pending.isEmpty) {
          return const Text(
            'Nenhum convite para duelo no momento.',
            style: TextStyle(color: Colors.white54),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pending.length,
          itemBuilder: (context, index) {
            final challenge = pending[index];
            return Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Você foi desafiado!',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Duelo: ${getNomeMetricaGlobal(challenge.metric)} (${challenge.durationDays} dias)',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _repository.respondChallenge(
                              challenge: challenge,
                              accept: false,
                            ),
                            child: const Text('Recusar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                            ),
                            onPressed: () => _repository.respondChallenge(
                              challenge: challenge,
                              accept: true,
                            ),
                            child: const Text(
                              'ENTRAR',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendInvites() {
    return StreamBuilder<List<ArenaFriendRequest>>(
      stream: _repository.watchPendingFriendRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Text(
            'Nenhum pedido de amizade pendente.',
            style: TextStyle(color: Colors.white54),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return Card(
              color: AppColors.surface,
              child: ListTile(
                leading: UserAvatar(
                  photoUrl: request.requesterPhoto,
                  name: request.requesterName,
                  radius: 20,
                ),
                title: Text(
                  request.requesterName,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white30),
                      onPressed: () => _respondFriendRequest(request, false),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                      ),
                      onPressed: () => _respondFriendRequest(request, true),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateChallenge() {
    var metric = 'constancy';
    var duration = 30;
    final selected = <ArenaFriendship>[];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Montar Duelo ⚔️',
                style: TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: metric,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(
                    value: 'constancy',
                    child: Text('Frequência (Dias Treinados)'),
                  ),
                  DropdownMenuItem(
                    value: 'volume',
                    child: Text('Força Bruta (Carga Movida)'),
                  ),
                  DropdownMenuItem(
                    value: 'bodyFatPercentage',
                    child: Text('Maior Perda de % Gordura'),
                  ),
                  DropdownMenuItem(
                    value: 'weight',
                    child: Text('Maior Perda de Peso (kg)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setModalState(() => metric = value);
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: duration,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 Dias (Tiro Curto)')),
                  DropdownMenuItem(value: 30, child: Text('30 Dias (Padrão)')),
                  DropdownMenuItem(value: 60, child: Text('60 Dias (Maratona)')),
                ],
                onChanged: (value) {
                  if (value != null) setModalState(() => duration = value);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Quem vai participar?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ArenaFriendship>>(
                  stream: _repository.watchFriends(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final friends = snapshot.data!;
                    if (friends.isEmpty) {
                      return const Center(
                        child: Text(
                          'Você não tem amigos na rede para convidar.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        final isSelected = selected.any(
                          (item) => item.otherUserId == friend.otherUserId,
                        );
                        return CheckboxListTile(
                          activeColor: Colors.deepOrangeAccent,
                          value: isSelected,
                          secondary: UserAvatar(
                            photoUrl: friend.otherUserPhoto,
                            name: friend.otherUserName,
                            radius: 16,
                          ),
                          title: Text(
                            friend.otherUserName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          onChanged: (checked) => setModalState(() {
                            if (checked == true) {
                              selected.add(friend);
                            } else {
                              selected.removeWhere(
                                (item) => item.otherUserId == friend.otherUserId,
                              );
                            }
                          }),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                  ),
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          await _repository.createChallenge(
                            metric: metric,
                            durationDays: duration,
                            invitedFriends: selected,
                          );
                          if (!sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          if (mounted) {
                            _showMessage(
                              'Duelo criado! Convites enviados.',
                              backgroundColor: Colors.deepOrangeAccent,
                            );
                          }
                        },
                  child: Text(
                    'LANÇAR DESAFIO PARA ${selected.length} AMIGOS',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }
}
