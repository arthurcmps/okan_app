import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/academy_link_requests_service.dart';

class AcademyLinkRequestsPage extends StatefulWidget {
  const AcademyLinkRequestsPage({super.key, this.service});

  final AcademyLinkRequestsService? service;

  @override
  State<AcademyLinkRequestsPage> createState() =>
      _AcademyLinkRequestsPageState();
}

class _AcademyLinkRequestsPageState extends State<AcademyLinkRequestsPage> {
  late final AcademyLinkRequestsService _service;

  final List<_LinkRequest> _requests = [];
  String? _nextCursor;
  String? _error;
  String? _respondingId;
  bool _loading = false;

  bool get _busy => _loading || _respondingId != null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AcademyLinkRequestsService();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    if (more && _nextCursor == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _service.listMyAcademyLinkRequests(
        cursor: more ? _nextCursor : null,
      );

      final rawRequests = result['requests'];
      final nextCursor = result['nextCursor'];

      if (rawRequests is! List ||
          (nextCursor != null && nextCursor is! String)) {
        throw const FormatException('Página inválida.');
      }

      final page = rawRequests.map(_LinkRequest.fromData).toList();

      if (!mounted) return;

      setState(() {
        if (!more) _requests.clear();

        final existingIds = _requests.map((item) => item.id).toSet();
        _requests.addAll(page.where((item) => existingIds.add(item.id)));
        _nextCursor = nextCursor as String?;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = academyLinkRequestErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _respond(_LinkRequest request, bool accept) async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(accept ? 'Aceitar vínculo?' : 'Recusar solicitação?'),
        content: Text(
          accept
              ? 'Você deseja se vincular à academia '
                    '${request.academyName} como aluno?'
              : 'Você deseja recusar a solicitação da academia '
                    '${request.academyName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(accept ? 'Aceitar' : 'Recusar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _busy) return;

    setState(() => _respondingId = request.id);

    try {
      await _service.respondStudentLink(requestId: request.id, accept: accept);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept ? 'Vínculo aceito.' : 'Solicitação recusada.'),
        ),
      );

      await _load();
    } catch (error, stackTrace) {
  debugPrint('AcademyLinkRequestsPage/load: $error');
  debugPrintStack(stackTrace: stackTrace);

  if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(academyLinkRequestErrorMessage(error))),
      );

      // Reconsulta o estado: o pedido pode ter expirado ou sido cancelado.
      await _load();
    } finally {
      if (mounted) {
        setState(() => _respondingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Solicitações de academias'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!_busy) await _load();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Confira a academia antes de aceitar o vínculo.',
              style: TextStyle(color: AppColors.textSub),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: AppColors.textSub),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _load(
                              more: _requests.isNotEmpty && _nextCursor != null,
                            ),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            if (!_loading && _error == null && _requests.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Você ainda não recebeu solicitações de academias.',
                    style: TextStyle(color: AppColors.textSub),
                  ),
                ),
              ),
            ..._requests.map(_buildRequest),
            if (_nextCursor != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Carregar mais'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequest(_LinkRequest request) {
    final responding = _respondingId == request.id;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.academyName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Estado: ${request.statusLabel}',
              style: const TextStyle(color: AppColors.textSub),
            ),
            const SizedBox(height: 4),
            Text(
              'Prazo: ${dateFormat.format(request.expiresAt)}',
              style: const TextStyle(color: AppColors.textSub),
            ),
            if (request.status == 'pending') ...[
              const SizedBox(height: 16),
              if (responding)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _respond(request, false),
                        child: const Text('Recusar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : () => _respond(request, true),
                        child: const Text('Aceitar'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinkRequest {
  const _LinkRequest({
    required this.id,
    required this.academyName,
    required this.status,
    required this.expiresAt,
  });

  final String id;
  final String academyName;
  final String status;
  final DateTime expiresAt;

  static _LinkRequest fromData(dynamic value) {
    if (value is! Map) {
      throw const FormatException('Solicitação inválida.');
    }

    final id = value['requestId'];
    final name = value['academyName'];
    final status = value['status'];
    final expiresAtMs = value['expiresAtMs'];

    const statuses = {
      'pending',
      'accepted',
      'rejected',
      'expired',
      'cancelled',
    };

    if (id is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{16,80}$').hasMatch(id) ||
        status is! String ||
        !statuses.contains(status) ||
        expiresAtMs is! int ||
        expiresAtMs < 0 ||
        (name != null && name is! String)) {
      throw const FormatException('Solicitação inválida.');
    }

    return _LinkRequest(
      id: id,
      academyName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'Academia sem nome disponível',
      status: status,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMs),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pendente';
      case 'accepted':
        return 'Aceita';
      case 'rejected':
        return 'Recusada';
      case 'expired':
        return 'Expirada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Indisponível';
    }
  }
}
