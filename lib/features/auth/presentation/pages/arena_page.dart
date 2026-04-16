import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';

// Helper global para nomear as métricas
String getNomeMetricaGlobal(String metric) {
  switch (metric) {
    case 'bodyFatPercentage': return '% de Gordura';
    case 'weight': return 'Perda de Peso';
    case 'constancy': return 'Frequência de Treinos';
    case 'volume': return 'Carga Total Movida';
    default: return 'Desafio';
  }
}

class ArenaPage extends StatefulWidget {
  const ArenaPage({super.key});

  @override
  State<ArenaPage> createState() => _ArenaPageState();
}

class _ArenaPageState extends State<ArenaPage> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  
  Map<String, dynamic>? _usuarioEncontrado;
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarNotificacaoArena(String targetUserId, String titulo, String corpo) async {
    if (targetUserId == user?.uid) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('notifications').add({
        'type': 'arena',
        'title': titulo,
        'body': corpo,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erro ao enviar notificação da arena: $e");
    }
  }

  Future<void> _buscarAmigo() async {
    final email = _searchCtrl.text.trim().toLowerCase();
    if (email.isEmpty || email == user?.email) return;

    setState(() { _buscando = true; _usuarioEncontrado = null; });

    try {
      final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).where('tipo', isEqualTo: 'aluno').limit(1).get();
      if (query.docs.isNotEmpty) {
        setState(() {
          _usuarioEncontrado = query.docs.first.data();
          _usuarioEncontrado!['uid'] = query.docs.first.id;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhum atleta encontrado com esse e-mail.")));
      }
    } catch (e) {
      debugPrint("Erro na busca: $e");
    } finally {
      setState(() => _buscando = false);
    }
  }

  Future<void> _enviarConvite() async {
    if (_usuarioEncontrado == null || user == null) return;
    final receiverId = _usuarioEncontrado!['uid'];

    // =================================================================
    // TRAVA DE SEGURANÇA: Verifica se já existe amizade ou convite
    // =================================================================
    
    // 1. Verifica se EU já enviei um convite para ele(a) (Pendente ou Aceito)
    final enviouParaEle = await FirebaseFirestore.instance.collection('friendships')
        .where('requesterId', isEqualTo: user!.uid)
        .where('receiverId', isEqualTo: receiverId)
        .get();

    // 2. Verifica se ELE(A) já me enviou um convite (Pendente ou Aceito)
    final enviouParaMim = await FirebaseFirestore.instance.collection('friendships')
        .where('requesterId', isEqualTo: receiverId)
        .where('receiverId', isEqualTo: user!.uid)
        .get();

    // Se encontrou qualquer documento, significa que o vínculo já existe
    if (enviouParaEle.docs.isNotEmpty || enviouParaMim.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vocês já são amigos ou já existe um convite pendente!"),
            backgroundColor: Colors.amber, // Cor de alerta
          )
        );
      }
      setState(() => _usuarioEncontrado = null);
      _searchCtrl.clear();
      return; // Interrompe a função aqui para não criar duplicação
    }
    // =================================================================

    // Se passou pela trava, continua o envio normal
    final meuDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final meuNome = meuDoc.data()?['name'] ?? meuDoc.data()?['nome'] ?? 'Atleta';

    await FirebaseFirestore.instance.collection('friendships').add({
      'requesterId': user!.uid,
      'requesterName': meuNome,
      'requesterPhoto': meuDoc.data()?['photoUrl'],
      'receiverId': receiverId,
      'receiverName': _usuarioEncontrado!['name'] ?? _usuarioEncontrado!['nome'] ?? 'Atleta',
      'receiverPhoto': _usuarioEncontrado!['photoUrl'],
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _enviarNotificacaoArena(receiverId, "Novo Convite na Arena 🤝", "$meuNome quer adicionar você como amigo!");

    setState(() => _usuarioEncontrado = null);
    _searchCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pedido de amizade enviado!"), backgroundColor: AppColors.primary)
      );
    }
  }

  Future<void> _responderConvite(String docId, bool aceitou, String requesterId) async {
    if (aceitou) {
      await FirebaseFirestore.instance.collection('friendships').doc(docId).update({'status': 'accepted'});
      
      final meuDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final meuNome = meuDoc.data()?['name'] ?? meuDoc.data()?['nome'] ?? 'Atleta';
      await _enviarNotificacaoArena(requesterId, "Convite Aceito! ⚔️", "$meuNome agora é seu amigo na Arena Okan.");

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Amigo adicionado à Arena!"), backgroundColor: AppColors.success));
    } else {
      await FirebaseFirestore.instance.collection('friendships').doc(docId).delete();
    }
  }

  void _confirmarSaidaDuelo(String docId) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Abandonar Duelo?", style: TextStyle(color: Colors.white)),
        content: const Text("Tem certeza que deseja sair desta batalha? Você será removido do ranking.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ficar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('challenges').doc(docId).update({
                'participantIds': FieldValue.arrayRemove([user!.uid]),
                'participants.${user!.uid}': FieldValue.delete(),
              });
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você saiu do duelo com sucesso."), backgroundColor: Colors.white24));
            },
            child: const Text("Abandonar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  void _confirmarExclusaoAmigo(String friendshipDocId, String nomeAmigo) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Desfazer Amizade?", style: TextStyle(color: Colors.white)),
        content: Text("Tem certeza que deseja remover $nomeAmigo da sua lista de amigos?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('friendships').doc(friendshipDocId).delete();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Amizade desfeita."), backgroundColor: Colors.white24));
            },
            child: const Text("Remover Amigo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Arena Okan ⚔️", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.deepOrangeAccent,
          labelColor: Colors.deepOrangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Duelos"),
            Tab(text: "Meus Amigos"),
            Tab(text: "Buscar"),
            Tab(text: "Convites"),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0 
        ? FloatingActionButton.extended(
            backgroundColor: Colors.deepOrangeAccent,
            icon: const Icon(Icons.add_moderator, color: Colors.white),
            label: const Text("NOVO DUELO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => _abrirModalCriarDueloEmGrupo(),
          )
        : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDuelosAba(),
          _buildAmigosAba(),
          _buildBuscarAba(),
          _buildConvitesAba(),
        ],
      ),
    );
  }

  Widget _buildDuelosAba() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('challenges')
          .where('participantIds', arrayContains: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Erro: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));

        final meusDuelos = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participantes = data['participants'] as Map<String, dynamic>? ?? {};
          return participantes[user!.uid]?['status'] == 'accepted';
        }).toList();

        meusDuelos.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final tA = dataA['startDate'] as Timestamp?;
          final tB = dataB['startDate'] as Timestamp?;
          if (tA == null || tB == null) return 0;
          return tB.compareTo(tA); 
        });

        if (meusDuelos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined, size: 60, color: Colors.white24),
                SizedBox(height: 16),
                Text("Nenhum duelo ativo.", style: TextStyle(color: Colors.white54, fontSize: 16)),
                Text("Clique em 'NOVO DUELO' para começar!", style: TextStyle(color: Colors.white30, fontSize: 14)),
              ],
            )
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
          itemCount: meusDuelos.length,
          itemBuilder: (context, index) {
            final doc = meusDuelos[index];
            final data = doc.data() as Map<String, dynamic>;
            final participantes = data['participants'] as Map<String, dynamic>;
            final metricaNome = getNomeMetricaGlobal(data['metric']);
            
            final startDate = (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
            final duration = data['durationDays'] as int? ?? 30;
            final endDate = startDate.add(Duration(days: duration));
            final isEncerrado = DateTime.now().isAfter(endDate);
            final diasRestantes = isEncerrado ? 0 : endDate.difference(DateTime.now()).inDays;

            List<String> nomes = [];
            participantes.forEach((key, value) {
              if (value['status'] == 'accepted') nomes.add(value['name'].split(' ')[0]);
            });

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => DuelRoomPage(desafioDoc: doc, isEncerrado: isEncerrado)
                ));
              },
              child: Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), 
                  side: BorderSide(color: isEncerrado ? Colors.amber.withOpacity(0.5) : Colors.deepOrangeAccent.withOpacity(0.5))
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: isEncerrado ? Colors.amber.withOpacity(0.2) : Colors.deepOrangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                isEncerrado ? "DUELO ENCERRADO 🏅" : "Duelo de $metricaNome", 
                                style: TextStyle(color: isEncerrado ? Colors.amber : Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isEncerrado) Text("$diasRestantes dias restantes", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(width: 8),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.exit_to_app, color: Colors.white30, size: 20),
                                tooltip: "Abandonar Duelo",
                                onPressed: () => _confirmarSaidaDuelo(doc.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text("Arena: ${nomes.length} Atletas", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(nomes.isEmpty ? "Aguardando aceites..." : nomes.join(', '), style: const TextStyle(color: Colors.white54, fontSize: 14)),
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

  Widget _buildConvitesAba() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Convites de Duelo ⚔️", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          _buildConvitesDueloLista(),
          
          const SizedBox(height: 30),
          
          const Text("Pedidos de Amizade 🤝", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 10),
          _buildConvitesAmizadeLista(),
        ],
      ),
    );
  }

  Widget _buildConvitesDueloLista() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('challenges').where('participantIds', arrayContains: user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));

        final pendentes = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participantes = data['participants'] as Map<String, dynamic>? ?? {};
          return participantes[user!.uid]?['status'] == 'pending';
        }).toList();

        if (pendentes.isEmpty) return const Text("Nenhum convite para duelo no momento.", style: TextStyle(color: Colors.white54));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pendentes.length,
          itemBuilder: (context, index) {
            final doc = pendentes[index];
            final data = doc.data() as Map<String, dynamic>;
            final metricaNome = getNomeMetricaGlobal(data['metric']);
            final duration = data['durationDays'] as int? ?? 30;

            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amber)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Você foi desafiado!", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Duelo: $metricaNome ($duration dias)", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.white54, side: const BorderSide(color: Colors.white24)),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('challenges').doc(doc.id).update({
                                'participantIds': FieldValue.arrayRemove([user!.uid]),
                                'participants.${user!.uid}': FieldValue.delete(),
                              });
                            },
                            child: const Text("Recusar"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                            onPressed: () async {
                              final meuDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
                              String chaveBanco = data['metric'] == 'weight' ? 'peso' : data['metric'];
                              double startVal = 0.0;
                              
                              if (data['metric'] == 'weight' || data['metric'] == 'bodyFatPercentage') {
                                startVal = (meuDoc.data()?[chaveBanco] ?? 0.0).toDouble();
                              }

                              final meuNome = meuDoc.data()?['name'] ?? meuDoc.data()?['nome'] ?? 'Atleta';

                              await FirebaseFirestore.instance.collection('challenges').doc(doc.id).update({
                                'participants.${user!.uid}.status': 'accepted',
                                'participants.${user!.uid}.startValue': startVal,
                              });

                              await _enviarNotificacaoArena(data['creatorId'], "Novo Gladiador na Arena! ⚔️", "$meuNome acabou de aceitar o seu desafio.");
                            },
                            child: const Text("ENTRAR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConvitesAmizadeLista() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('friendships').where('receiverId', isEqualTo: user!.uid).where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Text("Nenhum pedido de amizade pendente.", style: TextStyle(color: Colors.white54));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: UserAvatar(photoUrl: data['requesterPhoto'], name: data['requesterName'], radius: 20),
                title: Text(data['requesterName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.close, color: Colors.white30), onPressed: () => _responderConvite(doc.id, false, data['requesterId'])),
                    IconButton(icon: const Icon(Icons.check_circle, color: AppColors.success), onPressed: () => _responderConvite(doc.id, true, data['requesterId'])),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAmigosAba() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('friendships').where('status', isEqualTo: 'accepted').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final minhasAmizades = snapshot.data!.docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['requesterId'] == user!.uid || d['receiverId'] == user!.uid;
        }).toList();

        if (minhasAmizades.isEmpty) return const Center(child: Text("Adicione amigos na aba 'Buscar' para desafiá-los!", style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: minhasAmizades.length,
          itemBuilder: (context, index) {
            final doc = minhasAmizades[index];
            final data = doc.data() as Map<String, dynamic>;
            final souEu = data['requesterId'] == user!.uid;
            final nomeAmigo = souEu ? data['receiverName'] : data['requesterName'];
            
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: UserAvatar(photoUrl: souEu ? data['receiverPhoto'] : data['requesterPhoto'], name: nomeAmigo, radius: 20),
                title: Text(nomeAmigo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                  tooltip: "Desfazer Amizade",
                  onPressed: () => _confirmarExclusaoAmigo(doc.id, nomeAmigo),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBuscarAba() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Encontre um Atleta", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Digite o e-mail exato do usuário.", style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(hintText: "email@exemplo.com", hintStyle: const TextStyle(color: Colors.white24), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                child: IconButton(icon: _buscando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.search, color: Colors.black), onPressed: _buscando ? null : _buscarAmigo),
              )
            ],
          ),
          const SizedBox(height: 30),
          if (_usuarioEncontrado != null) ...[
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: UserAvatar(photoUrl: _usuarioEncontrado!['photoUrl'], name: _usuarioEncontrado!['name'] ?? _usuarioEncontrado!['nome'] ?? 'A', radius: 20),
              title: Text(_usuarioEncontrado!['name'] ?? _usuarioEncontrado!['nome'] ?? 'Atleta', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary), onPressed: _enviarConvite, child: const Text("Adicionar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
            )
          ]
        ],
      ),
    );
  }

  void _abrirModalCriarDueloEmGrupo() {
    String metricaSelecionada = 'constancy'; 
    int diasSelecionados = 30;
    List<Map<String, dynamic>> amigosSelecionados = [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  const Text("Montar Duelo ⚔️", style: TextStyle(color: Colors.deepOrangeAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  const Text("O que vamos disputar?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: metricaSelecionada,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.surface),
                    items: const [
                      DropdownMenuItem(value: 'constancy', child: Text("Frequência (Dias Treinados)")),
                      DropdownMenuItem(value: 'volume', child: Text("Força Bruta (Carga Movida)")),
                      DropdownMenuItem(value: 'bodyFatPercentage', child: Text("Maior Perda de % Gordura")),
                      DropdownMenuItem(value: 'weight', child: Text("Maior Perda de Peso (kg)")),
                    ],
                    onChanged: (val) => setStateModal(() => metricaSelecionada = val!),
                  ),
                  
                  const SizedBox(height: 20),

                  const Text("Duração do Duelo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: diasSelecionados,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: AppColors.surface),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text("15 Dias (Tiro Curto)")),
                      DropdownMenuItem(value: 30, child: Text("30 Dias (Padrão)")),
                      DropdownMenuItem(value: 60, child: Text("60 Dias (Maratona)")),
                    ],
                    onChanged: (val) => setStateModal(() => diasSelecionados = val!),
                  ),

                  const SizedBox(height: 20),
                  const Text("Quem vai participar?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('friendships').where('status', isEqualTo: 'accepted').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        
                        final minhasAmizades = snapshot.data!.docs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return d['requesterId'] == user!.uid || d['receiverId'] == user!.uid;
                        }).toList();

                        if (minhasAmizades.isEmpty) return const Text("Você não tem amigos na rede para convidar.", style: TextStyle(color: Colors.white54));

                        return ListView.builder(
                          itemCount: minhasAmizades.length,
                          itemBuilder: (context, index) {
                            final data = minhasAmizades[index].data() as Map<String, dynamic>;
                            final souEu = data['requesterId'] == user!.uid;
                            
                            final amigoId = souEu ? data['receiverId'] : data['requesterId'];
                            final nomeAmigo = souEu ? data['receiverName'] : data['requesterName'];
                            final fotoAmigo = souEu ? data['receiverPhoto'] : data['requesterPhoto'];

                            final isSelected = amigosSelecionados.any((amigo) => amigo['uid'] == amigoId);

                            return CheckboxListTile(
                              activeColor: Colors.deepOrangeAccent,
                              checkColor: Colors.white,
                              title: Text(nomeAmigo, style: const TextStyle(color: Colors.white)),
                              secondary: UserAvatar(photoUrl: fotoAmigo, name: nomeAmigo, radius: 16),
                              value: isSelected,
                              onChanged: (bool? checked) {
                                setStateModal(() {
                                  if (checked == true) {
                                    amigosSelecionados.add({'uid': amigoId, 'name': nomeAmigo, 'photoUrl': fotoAmigo});
                                  } else {
                                    amigosSelecionados.removeWhere((amigo) => amigo['uid'] == amigoId);
                                  }
                                });
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrangeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: amigosSelecionados.isEmpty ? null : () async {
                        
                        final meuDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
                        final meuNome = meuDoc.data()?['name'] ?? meuDoc.data()?['nome'] ?? 'Atleta';
                        final minhaFoto = meuDoc.data()?['photoUrl'];
                        String chaveBanco = metricaSelecionada == 'weight' ? 'peso' : metricaSelecionada;
                        
                        double meuStartVal = 0.0;
                        if (metricaSelecionada == 'weight' || metricaSelecionada == 'bodyFatPercentage') {
                          meuStartVal = (meuDoc.data()?[chaveBanco] ?? 0.0).toDouble();
                        }

                        List<String> todosIds = [user!.uid]; 
                        Map<String, dynamic> detalheParticipantes = {
                          user!.uid: {'name': meuNome, 'photoUrl': minhaFoto, 'status': 'accepted', 'startValue': meuStartVal}
                        };

                        for (var amigo in amigosSelecionados) {
                          todosIds.add(amigo['uid']);
                          detalheParticipantes[amigo['uid']] = {
                            'name': amigo['name'],
                            'photoUrl': amigo['photoUrl'],
                            'status': 'pending' 
                          };
                        }

                        await FirebaseFirestore.instance.collection('challenges').add({
                          'creatorId': user!.uid,
                          'metric': metricaSelecionada,
                          'durationDays': diasSelecionados,
                          'startDate': FieldValue.serverTimestamp(),
                          'participantIds': todosIds,
                          'participants': detalheParticipantes,
                          'imagensApagadas': false, // NOVO: Flag para controlar a deleção de fotos
                        });

                        String metricaLabel = getNomeMetricaGlobal(metricaSelecionada);
                        for (var amigo in amigosSelecionados) {
                          await _enviarNotificacaoArena(amigo['uid'], "Você foi desafiado! 🛡️", "$meuNome montou uma Arena de $metricaLabel.");
                        }

                        if (context.mounted) {
                          Navigator.pop(context); 
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Duelo criado! Convites enviados."), backgroundColor: Colors.deepOrangeAccent));
                        }
                      },
                      child: Text("LANÇAR DESAFIO PARA ${amigosSelecionados.length} AMIGOS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
}

// ==============================================================================
// SALA DO DUELO (Ranking + Mural "Tá Pago" + Deleção Automática)
// ==============================================================================
class DuelRoomPage extends StatefulWidget {
  final DocumentSnapshot desafioDoc;
  final bool isEncerrado;

  const DuelRoomPage({super.key, required this.desafioDoc, required this.isEncerrado});

  @override
  State<DuelRoomPage> createState() => _DuelRoomPageState();
}

class _DuelRoomPageState extends State<DuelRoomPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _postCtrl = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // GATILHO DE LIMPEZA DE FOTOS 🧹
    // Se o duelo acabou, disparamos a verificação para limpar o Storage e não gastar servidor
    if (widget.isEncerrado) {
      _verificarELimparImagens();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postCtrl.dispose();
    super.dispose();
  }

  // --- LÓGICA DE LIMPEZA (Garante privacidade e poupa custos) ---
  Future<void> _verificarELimparImagens() async {
    final data = widget.desafioDoc.data() as Map<String, dynamic>;
    
    // Se já apagou antes, não precisa tentar de novo
    if (data['imagensApagadas'] == true) return;

    try {
      // 1. Vai à pasta específica deste duelo no Storage e lista tudo
      final storageRef = FirebaseStorage.instance.ref().child('arena_duels/${widget.desafioDoc.id}');
      final listResult = await storageRef.listAll();
      
      // 2. Deleta foto por foto silenciosamente
      for (var item in listResult.items) {
        await item.delete();
      }
      
      // 3. Marca no banco de dados que o "lixo foi levado" para não repetir
      await FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).update({
        'imagensApagadas': true
      });
      debugPrint("Imagens do duelo encerrado apagadas com sucesso.");
    } catch (e) {
      debugPrint("Erro na limpeza de imagens (ou pasta já estava vazia): $e");
    }
  }

  Future<void> _enviarNotificacaoArena(String targetUserId, String titulo, String corpo) async {
    if (targetUserId == user?.uid) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(targetUserId).collection('notifications').add({
        'type': 'arena',
        'title': titulo,
        'body': corpo,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Erro ao enviar notificação: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _calcularPlacar() async {
    final data = widget.desafioDoc.data() as Map<String, dynamic>;
    final metrica = data['metric'];
    final participantes = data['participants'] as Map<String, dynamic>;
    DateTime startDate = (data['startDate'] as Timestamp).toDate();
    DateTime endDate = startDate.add(Duration(days: data['durationDays'] ?? 30));
    DateTime limiteBusca = DateTime.now().isBefore(endDate) ? DateTime.now() : endDate;
    List<Map<String, dynamic>> ranking = [];

    for (var uid in data['participantIds']) {
      var pData = participantes[uid];
      if (pData['status'] != 'accepted') continue;
      double delta = 0.0;

      if (metrica == 'weight' || metrica == 'bodyFatPercentage') {
        String chaveBanco = metrica == 'weight' ? 'peso' : metrica; 
        double startVal = (pData['startValue'] ?? 0.0).toDouble();
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        double currentVal = (userDoc.data()?[chaveBanco] ?? 0.0).toDouble();
        delta = currentVal - startVal; 
      } else if (metrica == 'constancy' || metrica == 'volume') {
        var historySnap = await FirebaseFirestore.instance.collection('workout_history').where('studentId', isEqualTo: uid).get();
        double totalVolume = 0.0;
        int treinosValidos = 0;
        for (var doc in historySnap.docs) {
          DateTime dataTreino = (doc.data()['dataRealizacao'] as Timestamp).toDate();
          if (dataTreino.isAfter(startDate) && dataTreino.isBefore(limiteBusca)) {
            treinosValidos++;
            if (metrica == 'volume') {
              List exercicios = doc.data()['exercicios'] ?? [];
              for (var ex in exercicios) {
                double carga = double.tryParse(ex['carga']?.toString() ?? '0') ?? 0.0;
                totalVolume += carga; 
              }
            }
          }
        }
        delta = metrica == 'constancy' ? treinosValidos.toDouble() : totalVolume;
      }
      ranking.add({'uid': uid, 'name': pData['name'], 'photoUrl': pData['photoUrl'], 'delta': delta});
    }

    if (metrica == 'weight' || metrica == 'bodyFatPercentage') {
      ranking.sort((a, b) => a['delta'].compareTo(b['delta']));
    } else {
      ranking.sort((a, b) => b['delta'].compareTo(a['delta']));
    }
    return ranking;
  }

  // --- LÓGICA DA CÂMERA E MURAL ---
  Future<void> _tirarFotoEPostar() async {
    final ImagePicker picker = ImagePicker();
    // imageQuality em 60% comprime bem a foto sem perder os detalhes importantes, poupando dados!
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 60); 
    if (photo == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Lê a foto e envia para o Firebase Storage na pasta deste duelo específico
      final Uint8List fileBytes = await photo.readAsBytes();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${user!.uid}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('arena_duels/${widget.desafioDoc.id}/$fileName');
      
      await storageRef.putData(fileBytes);
      final imageUrl = await storageRef.getDownloadURL();

      // 2. Criar o Post no Firestore com a URL da foto
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final nome = userDoc.data()?['name'] ?? 'Atleta';
      final photoUrl = userDoc.data()?['photoUrl'];

      await FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').add({
        'authorId': user!.uid,
        'authorName': nome,
        'authorPhoto': photoUrl,
        'text': _postCtrl.text.trim().isEmpty ? "Tá pago na Arena! 🔥" : _postCtrl.text.trim(),
        'imageUrl': imageUrl, // Aqui vai o link da foto!
        'timestamp': FieldValue.serverTimestamp(),
        'reactions': {}, 
        'commentsCount': 0,
      });

      _postCtrl.clear();
      FocusScope.of(context).unfocus(); // Fecha o teclado
      
    } catch (e) {
      debugPrint("Erro no upload da foto: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao processar foto: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _publicarTextoNoMural() async {
    if (_postCtrl.text.trim().isEmpty) return;
    
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final nome = userDoc.data()?['name'] ?? 'Atleta';
    final photo = userDoc.data()?['photoUrl'];

    await FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').add({
      'authorId': user!.uid,
      'authorName': nome,
      'authorPhoto': photo,
      'text': _postCtrl.text.trim(),
      'imageUrl': null, 
      'timestamp': FieldValue.serverTimestamp(),
      'reactions': {}, 
      'commentsCount': 0,
    });

    _postCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _adicionarReacao(String postId, String emoji) async {
    final postRef = FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').doc(postId);
    
    FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> reactions = Map<String, dynamic>.from(snapshot.data()?['reactions'] ?? {});
      List<dynamic> uids = List.from(reactions[emoji] ?? []);

      if (uids.contains(user!.uid)) {
        uids.remove(user!.uid);
      } else {
        uids.add(user!.uid);
      }

      reactions[emoji] = uids;
      transaction.update(postRef, {'reactions': reactions});
    });
  }

  void _abrirComentarios(String postId, String authorName) {
    final TextEditingController commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("Comentários de $authorName", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(color: Colors.white24),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').doc(postId).collection('comments').orderBy('timestamp').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
                    final comments = snapshot.data!.docs;
                    if (comments.isEmpty) return const Center(child: Text("Seja o primeiro a comentar!", style: TextStyle(color: Colors.white54)));

                    return ListView.builder(
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index].data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(photoUrl: c['authorPhoto'], name: c['authorName'], radius: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c['authorName'], style: const TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(c['text'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Adicionar comentário...",
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepOrangeAccent),
                    onPressed: () async {
                      if (commentCtrl.text.trim().isEmpty) return;
                      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
                      
                      await FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').doc(postId).collection('comments').add({
                        'authorId': user!.uid,
                        'authorName': userDoc.data()?['name'] ?? 'Atleta',
                        'authorPhoto': userDoc.data()?['photoUrl'],
                        'text': commentCtrl.text.trim(),
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      
                      await FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').doc(postId).update({'commentsCount': FieldValue.increment(1)});
                      commentCtrl.clear();
                    },
                  )
                ],
              )
            ],
          ),
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.desafioDoc.data() as Map<String, dynamic>;
    final metricaNome = getNomeMetricaGlobal(data['metric']);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text("Duelo de $metricaNome", style: const TextStyle(color: Colors.white, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.deepOrangeAccent,
          labelColor: Colors.deepOrangeAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Placar", icon: Icon(Icons.leaderboard)),
            Tab(text: "Mural 'Tá Pago'", icon: Icon(Icons.camera_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbaPlacar(data),
          _buildAbaMural(),
        ],
      ),
    );
  }

  Widget _buildAbaPlacar(Map<String, dynamic> data) {
    final metrica = data['metric'];
    String sufixo = "";
    if (metrica == 'weight') sufixo = "kg";
    else if (metrica == 'bodyFatPercentage') sufixo = "%";
    else if (metrica == 'constancy') sufixo = "treinos";
    else if (metrica == 'volume') sufixo = "kg movidos";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (widget.isEncerrado) 
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
              child: const Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber),
                  SizedBox(width: 12),
                  Expanded(child: Text("Batalha Encerrada! As fotos confidenciais deste duelo já foram varridas do servidor.", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _calcularPlacar(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Carregando placar...", style: TextStyle(color: Colors.white54)));

                final ranking = snapshot.data!;

                return ListView.builder(
                  itemCount: ranking.length,
                  itemBuilder: (context, index) {
                    final atleta = ranking[index];
                    final delta = atleta['delta'] as double;
                    String progressoStr;
                    Color corDelta = Colors.white54;
                    bool isMetricaNegativa = (metrica == 'weight' || metrica == 'bodyFatPercentage');

                    if (isMetricaNegativa) {
                      if (delta < 0) { progressoStr = "${delta.toStringAsFixed(1)} $sufixo"; corDelta = AppColors.success; }
                      else if (delta > 0) { progressoStr = "+${delta.toStringAsFixed(1)} $sufixo"; corDelta = AppColors.error; }
                      else { progressoStr = "0.0 $sufixo"; }
                    } else {
                      progressoStr = "${delta.toInt()} $sufixo";
                      corDelta = delta > 0 ? AppColors.success : Colors.white54;
                    }

                    Widget posicao;
                    if (index == 0) posicao = const Icon(Icons.workspace_premium, color: Colors.amber, size: 32);
                    else if (index == 1) posicao = const Icon(Icons.workspace_premium, color: Colors.grey, size: 28);
                    else if (index == 2) posicao = const Icon(Icons.workspace_premium, color: Colors.brown, size: 28);
                    else posicao = Text("${index + 1}º", style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold));

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: index == 0 ? Colors.amber.withOpacity(0.5) : Colors.transparent)),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 30, child: Center(child: posicao)),
                            const SizedBox(width: 8),
                            UserAvatar(photoUrl: atleta['photoUrl'], name: atleta['name'], radius: 18),
                          ],
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(atleta['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            if (index == 0 && widget.isEncerrado) const Text("Guerreiro Implacável 🏅", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: corDelta.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: corDelta.withOpacity(0.5))),
                              child: Text(progressoStr, style: TextStyle(color: corDelta, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            if (atleta['uid'] != user!.uid) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.whatshot, color: Colors.deepOrangeAccent),
                                tooltip: "Mandar provocação!",
                                onPressed: () async {
                                  final meuDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
                                  final meuNome = meuDoc.data()?['name'] ?? 'Alguém';
                                  await _enviarNotificacaoArena(atleta['uid'], "A Arena tá pegando fogo! 🔥", "$meuNome está de olho no seu placar. Vai deixar passar?");
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Provocação enviada!"), backgroundColor: Colors.deepOrangeAccent));
                                },
                              ),
                            ]
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

  Widget _buildAbaMural() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('challenges').doc(widget.desafioDoc.id).collection('posts').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("O muro está limpo. Seja o primeiro a postar!", style: TextStyle(color: Colors.white54)));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final postDoc = snapshot.data!.docs[index];
                  final post = postDoc.data() as Map<String, dynamic>;
                  final dataData = (post['timestamp'] as Timestamp?)?.toDate();
                  final dataFormatada = dataData != null ? DateFormat("dd/MM 'às' HH:mm").format(dataData) : '';
                  final reacoes = Map<String, dynamic>.from(post['reactions'] ?? {});
                  final hasImage = post['imageUrl'] != null && post['imageUrl'].toString().isNotEmpty;

                  return Card(
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserAvatar(photoUrl: post['authorPhoto'], name: post['authorName'], radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(post['authorName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(dataFormatada, style: const TextStyle(color: Colors.white30, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(post['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                          
                          // Mostra a foto só se o duelo NÃO tiver encerrado (e não tiverem sido apagadas)
                          if (hasImage && !widget.isEncerrado) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                post['imageUrl'], 
                                width: double.infinity, 
                                height: 250, 
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white24)));
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100, color: Colors.black12,
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 40)),
                                  );
                                },
                              ),
                            ),
                          ],
                          
                          // Mensagem de Privacidade se o duelo já acabou e tinha foto
                          if (hasImage && widget.isEncerrado) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.white30, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text("Esta foto foi removida dos servidores para proteger a privacidade dos atletas após o fim do duelo.", style: TextStyle(color: Colors.white30, fontSize: 12))),
                                ],
                              ),
                            )
                          ],

                          const Divider(color: Colors.white10, height: 30),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildBotaoReacao(postDoc.id, '🔥', reacoes['🔥']),
                                  const SizedBox(width: 8),
                                  _buildBotaoReacao(postDoc.id, '💪', reacoes['💪']),
                                  const SizedBox(width: 8),
                                  _buildBotaoReacao(postDoc.id, '🐢', reacoes['🐢']),
                                ],
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 18),
                                label: Text("${post['commentsCount'] ?? 0} Comentários", style: const TextStyle(color: Colors.white54)),
                                onPressed: () => _abrirComentarios(postDoc.id, post['authorName']),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        
        // Apenas deixa postar se o duelo ainda estiver ativo!
        if (!widget.isEncerrado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.deepOrangeAccent, strokeWidth: 2)) 
                        : const Icon(Icons.camera_alt, color: Colors.deepOrangeAccent),
                    onPressed: _isUploading ? null : _tirarFotoEPostar,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _postCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Provoque ou mostre que tá pago...",
                        hintStyle: TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.deepOrangeAccent),
                    onPressed: _isUploading ? null : _publicarTextoNoMural,
                  )
                ],
              ),
            ),
          )
      ],
    );
  }

  Widget _buildBotaoReacao(String postId, String emoji, dynamic listaUids) {
    List uids = listaUids ?? [];
    bool curti = uids.contains(user!.uid);
    return InkWell(
      onTap: () => _adicionarReacao(postId, emoji),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: curti ? Colors.deepOrangeAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: curti ? Colors.deepOrangeAccent : Colors.white10),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            if (uids.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(uids.length.toString(), style: TextStyle(color: curti ? Colors.deepOrangeAccent : Colors.white54, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }
}