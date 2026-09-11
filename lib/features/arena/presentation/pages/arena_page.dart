import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/okan_async_state.dart';
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
  late Stream<List<ArenaChallenge>> _challengesStream;
  late Stream<List<ArenaChallenge>> _challengeInvitesStream;
  late Stream<List<ArenaFriendship>> _friendsStream;
  late Stream<List<ArenaFriendRequest>> _friendRequestsStream;
  final TextEditingController _searchCtrl = TextEditingController();

  ArenaFriendCandidate? _foundUser;
  bool _searching = false;
  bool _sendingFriendRequest = false;

  String get _uid => _repository.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirebaseArenaRepository();
    if (_uid.isEmpty) {
      _challengesStream = const Stream.empty();
      _challengeInvitesStream = const Stream.empty();
      _friendsStream = const Stream.empty();
      _friendRequestsStream = const Stream.empty();
    } else {
      _challengesStream = _repository.watchChallenges();
      _challengeInvitesStream = _repository.watchChallenges();
      _friendsStream = _repository.watchFriends();
      _friendRequestsStream = _repository.watchPendingFriendRequests();
    }
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
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Não foi possível buscar o atleta. Tente novamente.',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final candidate = _foundUser;
    if (candidate == null || _sendingFriendRequest) return;
    setState(() => _sendingFriendRequest = true);
    try {
      await _repository.sendFriendRequest(candidate);
      if (!mounted) return;
      setState(() => _foundUser = null);
      _searchCtrl.clear();
      _showMessage(
        'Pedido de amizade enviado!',
        backgroundColor: AppColors.primary,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Não foi possível enviar o pedido. Tente novamente.',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) setState(() => _sendingFriendRequest = false);
    }
  }

  Future<void> _respondFriendRequest(
    ArenaFriendRequest request,
    bool accept,
  ) async {
    try {
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
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível responder ao convite. Tente novamente.',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  Future<void> _respondChallenge(
    ArenaChallenge challenge,
    bool accept,
  ) async {
    try {
      await _repository.respondChallenge(
        challenge: challenge,
        accept: accept,
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível responder ao duelo. Tente novamente.',
          backgroundColor: AppColors.error,
        );
      }
    }
  }

  void _confirmRemoveFriend(ArenaFriendship friendship) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
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
              try {
                await _repository.removeFriendship(friendship.id);
                if (mounted) _showMessage('Amizade desfeita.');
              } catch (_) {
                if (mounted) {
                  _showMessage(
                    'Não foi possível desfazer a amizade. Tente novamente.',
                    backgroundColor: AppColors.error,
                  );
                }
              }
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
        scrollable: true,
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
              try {
                await _repository.leaveChallenge(challenge.id);
                if (mounted) _showMessage('Você saiu do duelo com sucesso.');
              } catch (_) {
                if (mounted) {
                  _showMessage(
                    'Não foi possível sair do duelo. Tente novamente.',
                    backgroundColor: AppColors.error,
                  );
                }
              }
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
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: OkanMessageState(
          key: ValueKey('arena-session-required'),
          icon: Icons.lock_outline,
          title: 'Sessão encerrada',
          description: 'Entre novamente para acessar a Arena.',
          isError: true,
          announce: true,
        ),
      );
    }

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
            color: AppColors.competition,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.competition,
          labelColor: AppColors.competition,
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
              backgroundColor: AppColors.competition,
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
      stream: _challengesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OkanMessageState(
            key: const ValueKey('arena-challenges-error'),
            icon: Icons.cloud_off_outlined,
            title: 'Não foi possível carregar seus duelos',
            description: 'Verifique sua conexão e tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: () => setState(
              () => _challengesStream = _repository.watchChallenges(),
            ),
            isError: true,
            announce: true,
          );
        }
        if (!snapshot.hasData) {
          return const OkanLoadingState(
            key: ValueKey('arena-challenges-loading'),
            label: 'Carregando duelos',
          );
        }

        final challenges = snapshot.data!
            .where((challenge) =>
                challenge.participants[_uid]?.status == 'accepted')
            .toList(growable: false);

        if (challenges.isEmpty) {
          return OkanMessageState(
            key: const ValueKey('arena-challenges-empty'),
            icon: Icons.shield_outlined,
            title: 'Nenhum duelo ativo',
            description: 'Crie um duelo e convide seus amigos para começar.',
            actionLabel: 'Criar duelo',
            onAction: _openCreateChallenge,
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
                        : AppColors.competition.withOpacity(0.5),
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
                                    : AppColors.competition,
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
                            tooltip: 'Abandonar duelo',
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
      stream: _friendsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OkanMessageState(
            key: const ValueKey('arena-friends-error'),
            icon: Icons.people_outline,
            title: 'Não foi possível carregar seus amigos',
            description: 'Verifique sua conexão e tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: () => setState(
              () => _friendsStream = _repository.watchFriends(),
            ),
            isError: true,
            announce: true,
          );
        }
        if (!snapshot.hasData) {
          return const OkanLoadingState(label: 'Carregando amigos');
        }
        final friends = snapshot.data!;
        if (friends.isEmpty) {
          return OkanMessageState(
            key: const ValueKey('arena-friends-empty'),
            icon: Icons.people_outline,
            title: 'Nenhum amigo na Arena',
            description: 'Busque um atleta pelo e-mail para adicioná-lo.',
            actionLabel: 'Buscar atleta',
            onAction: () => _tabController.animateTo(2),
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
                  tooltip: 'Remover ${friend.otherUserName}',
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
    return SingleChildScrollView(
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
                    labelText: 'E-mail do atleta',
                    hintText: 'email@exemplo.com',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    if (!_searching) _searchFriend();
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                tooltip: 'Buscar atleta',
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _searching ? null : _searchFriend,
                icon: _searching
                    ? const Semantics(
                        liveRegion: true,
                        label: 'Buscando atleta',
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      )
                    : const Icon(Icons.search, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (_foundUser case final candidate?) _buildCandidateCard(candidate),
        ],
      ),
    );
  }

  Widget _buildCandidateCard(ArenaFriendCandidate candidate) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(16) >= 28;
            final identity = Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                UserAvatar(
                  photoUrl: candidate.photoUrl,
                  name: candidate.name,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    candidate.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
            final action = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: _sendingFriendRequest ? null : _sendFriendRequest,
              child: _sendingFriendRequest
                  ? const Semantics(
                      liveRegion: true,
                      label: 'Enviando pedido de amizade',
                      child: ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : const Text(
                      'Adicionar',
                      style: TextStyle(color: Colors.black),
                    ),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 16),
                  action,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                action,
              ],
            );
          },
        ),
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
      stream: _challengeInvitesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 240,
            child: OkanMessageState(
              key: const ValueKey('arena-challenge-invites-error'),
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar os convites de duelo',
              description: 'Verifique sua conexão e tente novamente.',
              actionLabel: 'Tentar novamente',
              onAction: () => setState(
                () => _challengeInvitesStream = _repository.watchChallenges(),
              ),
              isError: true,
              announce: true,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: OkanLoadingState(label: 'Carregando convites de duelo'),
          );
        }
        final pending = snapshot.data!
            .where(
              (challenge) =>
                  challenge.participants[_uid]?.status == 'pending',
            )
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
                            onPressed: () =>
                                _respondChallenge(challenge, false),
                            child: const Text('Recusar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                            ),
                            onPressed: () => _respondChallenge(challenge, true),
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
      stream: _friendRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 240,
            child: OkanMessageState(
              key: const ValueKey('arena-friend-invites-error'),
              icon: Icons.cloud_off_outlined,
              title: 'Não foi possível carregar os pedidos de amizade',
              description: 'Verifique sua conexão e tente novamente.',
              actionLabel: 'Tentar novamente',
              onAction: () => setState(
                () => _friendRequestsStream =
                    _repository.watchPendingFriendRequests(),
              ),
              isError: true,
              announce: true,
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: OkanLoadingState(label: 'Carregando pedidos de amizade'),
          );
        }
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
                      tooltip: 'Recusar pedido de ${request.requesterName}',
                      icon: const Icon(Icons.close, color: Colors.white30),
                      onPressed: () => _respondFriendRequest(request, false),
                    ),
                    IconButton(
                      tooltip: 'Aceitar pedido de ${request.requesterName}',
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
    final friendsStream = _repository.watchFriends();

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
                  stream: friendsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return OkanMessageState(
                        key: const ValueKey('arena-create-friends-error'),
                        icon: Icons.cloud_off_outlined,
                        title: 'Não foi possível carregar seus amigos',
                        description:
                            'Feche esta janela e tente novamente em instantes.',
                        isError: true,
                        announce: true,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const OkanLoadingState(
                        label: 'Carregando amigos para o duelo',
                      );
                    }
                    final friends = snapshot.data!;
                    if (friends.isEmpty) {
                      return const OkanMessageState(
                        icon: Icons.people_outline,
                        title: 'Nenhum amigo disponível',
                        description:
                            'Adicione amigos na Arena antes de criar um duelo.',
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
                          try {
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
                                backgroundColor: AppColors.competition,
                              );
                            }
                          } catch (_) {
                            if (mounted) {
                              _showMessage(
                                'Não foi possível criar o duelo. Tente novamente.',
                                backgroundColor: AppColors.error,
                              );
                            }
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
