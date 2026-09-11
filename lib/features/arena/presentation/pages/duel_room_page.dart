import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/okan_async_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/entities/arena_models.dart';
import '../../domain/repositories/arena_repository.dart';
import 'arena_page.dart';

class DuelRoomPage extends StatefulWidget {
  const DuelRoomPage({
    super.key,
    required this.challenge,
    required this.repository,
  });

  final ArenaChallenge challenge;
  final ArenaRepository repository;

  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<List<ArenaRankingEntry>> _rankingFuture;
  late Stream<List<ArenaPost>> _postsStream;
  final TextEditingController _postCtrl = TextEditingController();
  final Set<String> _sendingTaunts = <String>{};
  final Set<String> _updatingReactions = <String>{};
  bool _isPublishingPhoto = false;
  bool _isPublishingText = false;

  bool get _isPublishing => _isPublishingPhoto || _isPublishingText;

  String get _uid => widget.repository.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (_uid.isEmpty) {
      _rankingFuture = Future.value(const <ArenaRankingEntry>[]);
      _postsStream = const Stream<List<ArenaPost>>.empty();
      return;
    }
    _rankingFuture = widget.repository.calculateRanking(widget.challenge);
    _postsStream = widget.repository.watchPosts(widget.challenge.id);
    if (widget.challenge.isEnded) {
      widget.repository.cleanupChallengeImages(widget.challenge).catchError((_) {
        debugPrint('Não foi possível concluir a limpeza de imagens da Arena.');
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhotoAndPost() async {
    if (_isPublishing) return;
    setState(() => _isPublishingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
      );
      if (photo == null) return;

      await widget.repository.createPhotoPost(
        challengeId: widget.challenge.id,
        bytes: await photo.readAsBytes(),
        text: _postCtrl.text,
      );
      _postCtrl.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível publicar a foto. Tente novamente.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishingPhoto = false);
    }
  }

  Future<void> _postText() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty || _isPublishing) return;
    setState(() => _isPublishingText = true);
    try {
      await widget.repository.createTextPost(
        challengeId: widget.challenge.id,
        text: text,
      );
      _postCtrl.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        _showMessage('Publicação enviada.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível publicar a mensagem. Tente novamente.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishingText = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.competition,
      ),
    );
  }

  void _retryRanking() {
    setState(() {
      _rankingFuture = widget.repository.calculateRanking(widget.challenge);
    });
  }

  void _retryPosts() {
    setState(() {
      _postsStream = widget.repository.watchPosts(widget.challenge.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: OkanMessageState(
          key: ValueKey('duel-room-session-required'),
          icon: Icons.lock_outline,
          title: 'Sessão encerrada',
          description: 'Entre novamente para acessar este duelo.',
          isError: true,
          announce: true,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Duelo de ${getNomeMetricaGlobal(widget.challenge.metric)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: AppColors.competition,
          labelColor: AppColors.competition,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Placar', icon: Icon(Icons.leaderboard)),
            Tab(text: "Mural 'Tá Pago'", icon: Icon(Icons.camera_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRanking(), _buildWall()],
      ),
    );
  }

  Widget _buildRanking() {
    final metric = widget.challenge.metric;
    final suffix = switch (metric) {
      'weight' => 'kg',
      'bodyFatPercentage' => '%',
      'constancy' => 'treinos',
      'volume' => 'kg movidos',
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.challenge.isEnded)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: const Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Batalha Encerrada! As fotos confidenciais deste duelo são removidas do servidor.',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<ArenaRankingEntry>>(
              future: _rankingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const OkanLoadingState(
                    label: 'Carregando placar do duelo',
                  );
                }
                if (snapshot.hasError) {
                  return OkanMessageState(
                    key: const ValueKey('duel-ranking-error'),
                    icon: Icons.leaderboard_outlined,
                    title: 'Não foi possível carregar o placar',
                    description: 'Verifique sua conexão e tente novamente.',
                    actionLabel: 'Tentar novamente',
                    onAction: _retryRanking,
                    isError: true,
                    announce: true,
                  );
                }
                final ranking = snapshot.data ?? const <ArenaRankingEntry>[];
                if (ranking.isEmpty) {
                  return const OkanMessageState(
                    key: ValueKey('duel-ranking-empty'),
                    icon: Icons.leaderboard_outlined,
                    title: 'Placar ainda sem resultados',
                    description:
                        'Os resultados aparecerão quando houver participantes ativos.',
                  );
                }

                return ListView.builder(
                  itemCount: ranking.length,
                  itemBuilder: (context, index) {
                    final athlete = ranking[index];
                    final negativeMetric =
                        metric == 'weight' || metric == 'bodyFatPercentage';
                    final progress = negativeMetric
                        ? '${athlete.delta > 0 ? '+' : ''}${athlete.delta.toStringAsFixed(1)} $suffix'
                        : '${athlete.delta.toInt()} $suffix';
                    final progressColor = negativeMetric
                        ? (athlete.delta < 0
                              ? AppColors.success
                              : athlete.delta > 0
                              ? AppColors.error
                              : Colors.white54)
                        : (athlete.delta > 0
                              ? AppColors.success
                              : Colors.white54);

                    return _rankingCard(
                      index: index,
                      athlete: athlete,
                      progress: progress,
                      progressColor: progressColor,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingCard({
    required int index,
    required ArenaRankingEntry athlete,
    required String progress,
    required Color progressColor,
  }) {
    final isSendingTaunt = _sendingTaunts.contains(athlete.userId);
    final identity = Row(
      children: [
        SizedBox(
          width: 30,
          child: Center(child: _position(index)),
        ),
        const SizedBox(width: 8),
        UserAvatar(
          photoUrl: athlete.photoUrl,
          name: athlete.name,
          radius: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                athlete.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (index == 0 && widget.challenge.isEnded)
                const Text(
                  'Guerreiro Implacável 🏅',
                  style: TextStyle(color: Colors.amber),
                ),
            ],
          ),
        ),
      ],
    );
    final resultAndAction = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          progress,
          style: TextStyle(
            color: progressColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (athlete.userId != _uid)
          IconButton(
            icon: isSendingTaunt
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.competition,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.whatshot, color: AppColors.competition),
            tooltip: 'Provocar ${athlete.name}',
            onPressed: isSendingTaunt ? null : () => _sendTaunt(athlete),
          ),
      ],
    );

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(16) >= 28;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: resultAndAction,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                resultAndAction,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _position(int index) {
    if (index == 0) {
      return const Icon(Icons.workspace_premium, color: Colors.amber, size: 32);
    }
    if (index == 1) {
      return const Icon(Icons.workspace_premium, color: Colors.grey, size: 28);
    }
    if (index == 2) {
      return const Icon(Icons.workspace_premium, color: Colors.brown, size: 28);
    }
    return Text(
      '${index + 1}º',
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _sendTaunt(ArenaRankingEntry athlete) async {
    if (_sendingTaunts.contains(athlete.userId)) return;
    setState(() => _sendingTaunts.add(athlete.userId));
    try {
      final me = await widget.repository.loadCurrentProfile();
      await widget.repository.sendArenaNotification(
        targetUserId: athlete.userId,
        title: 'A Arena tá pegando fogo! 🔥',
        body: '${me.name} está de olho no seu placar. Vai deixar passar?',
      );
      if (mounted) _showMessage('Provocação enviada!');
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível enviar a provocação. Tente novamente.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingTaunts.remove(athlete.userId));
      }
    }
  }

  Widget _buildWall() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ArenaPost>>(
            stream: _postsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return OkanMessageState(
                  key: const ValueKey('duel-wall-error'),
                  icon: Icons.forum_outlined,
                  title: 'Não foi possível carregar o mural',
                  description: 'Verifique sua conexão e tente novamente.',
                  actionLabel: 'Tentar novamente',
                  onAction: _retryPosts,
                  isError: true,
                  announce: true,
                );
              }
              if (!snapshot.hasData) {
                return const OkanLoadingState(
                  label: 'Carregando mural do duelo',
                );
              }
              final posts = snapshot.data!;
              if (posts.isEmpty) {
                return const OkanMessageState(
                  key: ValueKey('duel-wall-empty'),
                  icon: Icons.forum_outlined,
                  title: 'Nenhuma publicação ainda',
                  description: 'Seja o primeiro a movimentar este duelo.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: posts.length,
                itemBuilder: (context, index) => _postCard(posts[index]),
              );
            },
          ),
        ),
        if (!widget.challenge.isEnded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Publicar foto no mural',
                    icon: _isPublishingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.competition,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: AppColors.competition,
                          ),
                    onPressed: _isPublishing ? null : _takePhotoAndPost,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _postCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Provoque ou mostre que tá pago...',
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Publicar mensagem no mural',
                    icon: _isPublishingText
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.competition,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: AppColors.competition,
                          ),
                    onPressed: _isPublishing ? null : _postText,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _postCard(ArenaPost post) {
    final hasImage = post.imageUrl?.isNotEmpty == true;
    final date = DateFormat("dd/MM 'às' HH:mm").format(post.createdAt);

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  photoUrl: post.authorPhoto,
                  name: post.authorName,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(date, style: const TextStyle(color: Colors.white30)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.text, style: const TextStyle(color: Colors.white)),
            if (hasImage && !widget.challenge.isEnded) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  post.imageUrl!,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (hasImage && widget.challenge.isEnded) ...[
              const SizedBox(height: 12),
              const Text(
                'Esta foto foi removida dos servidores após o fim do duelo.',
                style: TextStyle(color: Colors.white30),
              ),
            ],
            const Divider(color: Colors.white10, height: 30),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _reaction(post, '🔥'),
                    const SizedBox(width: 8),
                    _reaction(post, '💪'),
                    const SizedBox(width: 8),
                    _reaction(post, '🐢'),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _openComments(post),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white54,
                  ),
                  label: Text(
                    '${post.commentsCount} Comentários',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reaction(ArenaPost post, String emoji) {
    final ids = post.reactions[emoji] ?? const <String>[];
    final selected = ids.contains(_uid);
    final actionKey = '${post.id}:$emoji';
    final updating = _updatingReactions.contains(actionKey);
    final reactionName = switch (emoji) {
      '🔥' => 'fogo',
      '💪' => 'força',
      '🐢' => 'tartaruga',
      _ => emoji,
    };

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label:
          '${selected ? 'Remover' : 'Adicionar'} reação $reactionName. ${ids.length} reações.',
      child: InkWell(
        onTap: updating ? null : () => _toggleReaction(post, emoji),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.competition.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.competition : Colors.white10,
            ),
          ),
          child: Center(
            child: updating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.competition,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji),
                      if (ids.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          ids.length.toString(),
                          style: TextStyle(
                            color: selected
                                ? AppColors.competition
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReaction(ArenaPost post, String emoji) async {
    final actionKey = '${post.id}:$emoji';
    if (_updatingReactions.contains(actionKey)) return;
    setState(() => _updatingReactions.add(actionKey));
    try {
      await widget.repository.toggleReaction(
        challengeId: widget.challenge.id,
        postId: post.id,
        emoji: emoji,
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Não foi possível atualizar a reação. Tente novamente.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingReactions.remove(actionKey));
      }
    }
  }

  void _openComments(ArenaPost post) {
    final controller = TextEditingController();
    var commentsStream = widget.repository.watchComments(
      challengeId: widget.challenge.id,
      postId: post.id,
    );
    var sendingComment = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Comentários de ${post.authorName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<ArenaComment>>(
                      stream: commentsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return OkanMessageState(
                            key: const ValueKey('duel-comments-error'),
                            icon: Icons.chat_bubble_outline,
                            title: 'Não foi possível carregar os comentários',
                            description:
                                'Verifique sua conexão e tente novamente.',
                            actionLabel: 'Tentar novamente',
                            onAction: () => setSheetState(() {
                              commentsStream = widget.repository.watchComments(
                                challengeId: widget.challenge.id,
                                postId: post.id,
                              );
                            }),
                            isError: true,
                            announce: true,
                          );
                        }
                        if (!snapshot.hasData) {
                          return const OkanLoadingState(
                            label: 'Carregando comentários',
                          );
                        }
                        final comments = snapshot.data!;
                        if (comments.isEmpty) {
                          return const OkanMessageState(
                            icon: Icons.chat_bubble_outline,
                            title: 'Nenhum comentário ainda',
                            description: 'Seja o primeiro a comentar.',
                          );
                        }
                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return ListTile(
                              leading: UserAvatar(
                                photoUrl: comment.authorPhoto,
                                name: comment.authorName,
                                radius: 14,
                              ),
                              title: Text(
                                comment.authorName,
                                style: const TextStyle(
                                  color: AppColors.competition,
                                ),
                              ),
                              subtitle: Text(
                                comment.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            enabled: !sendingComment,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Adicionar comentário...',
                              hintStyle: TextStyle(color: Colors.white30),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Enviar comentário',
                          icon: sendingComment
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.competition,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: AppColors.competition,
                                ),
                          onPressed: sendingComment
                              ? null
                              : () async {
                                  final text = controller.text.trim();
                                  if (text.isEmpty) return;
                                  setSheetState(() => sendingComment = true);
                                  try {
                                    await widget.repository.addComment(
                                      challengeId: widget.challenge.id,
                                      postId: post.id,
                                      text: text,
                                    );
                                    if (!sheetContext.mounted) return;
                                    controller.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Comentário enviado.'),
                                        backgroundColor: AppColors.competition,
                                      ),
                                    );
                                  } catch (_) {
                                    if (sheetContext.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Não foi possível enviar o comentário. Tente novamente.',
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (sheetContext.mounted) {
                                      setSheetState(
                                        () => sendingComment = false,
                                      );
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}
