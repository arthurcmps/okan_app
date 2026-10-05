import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/run_image_share_service.dart';
import '../../domain/entities/run_session.dart';
import '../widgets/run_share_card.dart';

class RunSharePreviewPage extends StatefulWidget {
  const RunSharePreviewPage({
    super.key,
    required this.session,
    required this.ownerUid,
  });

  final RunSession session;
  final String ownerUid;

  @override
  State<RunSharePreviewPage> createState() => _RunSharePreviewPageState();
}

class _RunSharePreviewPageState extends State<RunSharePreviewPage> {
  final GlobalKey _cardKey = GlobalKey();
  final RunImageShareService _shareService = RunImageShareService();

  bool _sharing = false;

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.ownerUid;

  bool get _canShare =>
      mounted && _isOwner && widget.session.status == RunStatus.finished;

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing || !_canShare) return;

    final renderBox = buttonContext.findRenderObject();

    if (renderBox is! RenderBox || !renderBox.hasSize) return;

    final origin = renderBox.localToGlobal(Offset.zero) & renderBox.size;

    setState(() => _sharing = true);

    try {
      await precacheImage(
        const AssetImage('assets/images/logo_okan.png'),
        context,
        onError: (error, stackTrace) {
          // O cartão possui uma marca textual como alternativa.
        },
      );

      await WidgetsBinding.instance.endOfFrame;

      if (!_canShare) return;

      final boundary = _cardKey.currentContext?.findRenderObject();

      if (boundary is! RenderRepaintBoundary) {
        throw StateError('A prévia da corrida não está disponível.');
      }

      // O cartão mede 360 × 640. A escala 3 gera 1080 × 1920.
      final image = await boundary.toImage(pixelRatio: 3);

      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);

        if (data == null) {
          throw StateError('Não foi possível gerar o PNG.');
        }

        if (!_canShare) return;

        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );

        await _shareService.sharePng(
          bytes: bytes,
          sharePositionOrigin: origin,
          canShare: () => _canShare,
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      if (!mounted) return;
      if (!_canShare) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível compartilhar a imagem. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        if (snapshot.data?.uid != widget.ownerUid) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compartilhar corrida')),
            body: const Center(
              child: Text('A conta foi alterada. Reabra o histórico.'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Compartilhar corrida')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: RunShareCard(session: widget.session),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Compartilhe sua conquista com uma imagem '
                    'vertical para Stories.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSub),
                  ),
                  const SizedBox(height: 16),
                  Builder(
                    builder: (buttonContext) => ElevatedButton.icon(
                      onPressed: _sharing || !_canShare
                          ? null
                          : () => _share(buttonContext),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(
                        _sharing
                            ? 'Preparando imagem...'
                            : 'Compartilhar imagem',
                      ),
                    ),
                  ),
                  if (_sharing) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
