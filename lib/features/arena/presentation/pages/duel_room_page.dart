import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
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
  final TextEditingController _postCtrl = TextEditingController();
  bool _isUploading = false;

  String get _uid => widget.repository.currentUserId ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (widget.challenge.isEnded) {
      widget.repository.cleanupChallengeImages(widget.challenge).catchError((error) {
        debugPrint('Erro na limpeza de imagens da Arena: $error');
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
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 60,
    );
    if (photo == null) return;

    setState(() => _isUploading = true);
    try {
      await widget.repository.createPhotoPost(
        challengeId: widget.challenge.id,
        bytes: await photo.readAsBytes(),
        text: _postCtrl.text,
      );
      _postCtrl.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar foto: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _postText() async {
    final text = _postCtrl.text.trim();
    if (text.isEmpty) return;
    await widget.repository.createTextPost(
      challengeId: widget.challenge.id,
      text: text,
    );
    _postCtrl.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Duelo de ${getNomeMetricaGlobal(widget.challenge.metric)}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepOrangeAccent,
          labelColor: Colors.deepOrangeAccent,
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
              future: widget.repository.calculateRanking(widget.challenge),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrangeAccent,
                    ),
                  );
                }
                final ranking = snapshot.data ?? const <ArenaRankingEntry>[];
                if (ranking.isEmpty) {
                  return const Center(
                    child: Text(
                      'Carregando placar...',
                      style: TextStyle(color: Colors.white54),
                    ),
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

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
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
                          ],
                        ),
                        title: Text(
                          athlete.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: index == 0 && widget.challenge.isEnded
                            ? const Text(
                                'Guerreiro Implacável 🏅',
                                style: TextStyle(color: Colors.amber),
                              )
                            : null,
                        trailing: Row(
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
                                icon: const Icon(
                                  Icons.whatshot,
                                  color: Colors.deepOrangeAccent,
                                ),
                                tooltip: 'Mandar provocação!',
                                onPressed: () => _sendTaunt(athlete),
                              ),
                          ],
                        ),
                      ),
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
    final me = await widget.repository.loadCurrentProfile();
    await widget.repository.sendArenaNotification(
      targetUserId: athlete.userId,
      title: 'A Arena tá pegando fogo! 🔥',
      body: '${me.name} está de olho no seu placar. Vai deixar passar?',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Provocação enviada!'),
          backgroundColor: Colors.deepOrangeAccent,
        ),
      );
    }
  }

  Widget _buildWall() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ArenaPost>>(
            stream: widget.repository.watchPosts(widget.challenge.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.deepOrangeAccent,
                  ),
                );
              }
              final posts = snapshot.data!;
              if (posts.isEmpty) {
                return const Center(
                  child: Text(
                    'O muro está limpo. Seja o primeiro a postar!',
                    style: TextStyle(color: Colors.white54),
                  ),
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
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.deepOrangeAccent,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.deepOrangeAccent,
                          ),
                    onPressed: _isUploading ? null : _takePhotoAndPost,
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
                    icon: const Icon(
                      Icons.send,
                      color: Colors.deepOrangeAccent,
                    ),
                    onPressed: _isUploading ? null : _postText,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
    return InkWell(
      onTap: () => widget.repository.toggleReaction(
        challengeId: widget.challenge.id,
        postId: post.id,
        emoji: emoji,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.deepOrangeAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.deepOrangeAccent : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Text(emoji),
            if (ids.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                ids.length.toString(),
                style: TextStyle(
                  color: selected ? Colors.deepOrangeAccent : Colors.white54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openComments(ArenaPost post) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Comentários de ${post.authorName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ArenaComment>>(
                  stream: widget.repository.watchComments(
                    challengeId: widget.challenge.id,
                    postId: post.id,
                  ),
                  builder: (context, snapshot) {
                    final comments = snapshot.data ?? const <ArenaComment>[];
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'Seja o primeiro a comentar!',
                          style: TextStyle(color: Colors.white54),
                        ),
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
                              color: Colors.deepOrangeAccent,
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
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Adicionar comentário...',
                          hintStyle: TextStyle(color: Colors.white30),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.deepOrangeAccent,
                      ),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        await widget.repository.addComment(
                          challengeId: widget.challenge.id,
                          postId: post.id,
                          text: text,
                        );
                        controller.clear();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}
