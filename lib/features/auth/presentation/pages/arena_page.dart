import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';

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

  // ==========================================
  // MOTOR DE NOTIFICAÇÕES DA ARENA 🔔
  // ==========================================
  Future<void> _enviarNotificacaoArena(String targetUserId, String titulo, String corpo) async {
    if (targetUserId == user?.uid) return; // Não notifica a si mesmo
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
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

    // 🔔 DISPARA NOTIFICAÇÃO DE CONVITE ENVIADO
    await _enviarNotificacaoArena(receiverId, "Novo Convite na Arena 🤝", "$meuNome quer adicionar você como amigo!");

    setState(() => _usuarioEncontrado = null);
    _searchCtrl.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido de amizade enviado!"), backgroundColor: AppColors.primary));
  }

  Future<void> _responderConvite(String docId, bool aceitou, String requesterId) async {
    if (aceitou) {
      await FirebaseFirestore.instance.collection('friendships').doc(docId).update({'status': 'accepted'});
      
      // 🔔 DISPARA NOTIFICAÇÃO DE CONVITE ACEITO
      final meuDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final meuNome = meuDoc.data()?['name'] ?? meuDoc.data()?['nome'] ?? 'Atleta';
      await _enviarNotificacaoArena(requesterId, "Convite Aceito! ⚔️", "$meuNome agora é seu amigo na Arena Okan.");

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Amigo adicionado à Arena!"), backgroundColor: AppColors.success));
    } else {
      await FirebaseFirestore.instance.collection('friendships').doc(docId).delete();
    }
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

  // ==========================================
  // ABA: DUELOS
  // ==========================================
  Widget _buildDuelosAba() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('challenges').where('participantIds', arrayContains: user!.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));

        final meusDuelos = snapshot.data!.docs;

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
            
            if (data['participants'] == null) return const SizedBox.shrink(); 

            final metricaNome = data['metric'] == 'bodyFatPercentage' ? '% de Gordura' : 'Perda de Peso';
            final participantes = data['participants'] as Map<String, dynamic>;
            final meuStatus = participantes[user!.uid]?['status'] ?? 'pending';
            
            List<String> nomes = [];
            participantes.forEach((key, value) {
              if (value['status'] == 'accepted') nomes.add(value['name'].split(' ')[0]);
            });

            return GestureDetector(
              onTap: () {
                if (meuStatus == 'accepted') _abrirRankingDuelo(doc);
              },
              child: Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: meuStatus == 'pending' ? Colors.amber : Colors.deepOrangeAccent.withOpacity(0.5))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.deepOrangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text("Duelo de $metricaNome", style: const TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          Text(meuStatus == 'pending' ? "Novo Convite" : "Ver Placar 🏆", style: TextStyle(color: meuStatus == 'pending' ? Colors.amber : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      Text("Arena: ${nomes.length} Atletas", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(nomes.isEmpty ? "Aguardando aceites..." : nomes.join(', '), style: const TextStyle(color: Colors.white54, fontSize: 14)),
                      
                      if (meuStatus == 'pending') ...[
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
                                  double startVal = (meuDoc.data()?[chaveBanco] ?? 0.0).toDouble();
                                  final meuNome = meuDoc.data()?['name'] ?? meuDoc.data()?['nome'] ?? 'Atleta';

                                  await FirebaseFirestore.instance.collection('challenges').doc(doc.id).update({
                                    'participants.${user!.uid}.status': 'accepted',
                                    'participants.${user!.uid}.startValue': startVal,
                                  });

                                  // 🔔 DISPARA NOTIFICAÇÃO PARA O CRIADOR DO DUELO
                                  await _enviarNotificacaoArena(data['creatorId'], "Novo Gladiador na Arena! ⚔️", "$meuNome acabou de aceitar o seu desafio.");
                                },
                                child: const Text("ENTRAR NA ARENA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ]
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

  // ==========================================
  // O PLACAR (RANKING E MATEMÁTICA)
  // ==========================================
  void _abrirRankingDuelo(DocumentSnapshot desafioDoc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.leaderboard, color: Colors.deepOrangeAccent, size: 28),
                  SizedBox(width: 10),
                  Text("Placar ao Vivo", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              const Text("Os resultados são comparados de forma justa (Diferença do início até hoje). Ninguém vê seu peso real!", style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 20),
              
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _calcularPlacar(desafioDoc),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.deepOrangeAccent));
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Carregando dados da arena...", style: TextStyle(color: Colors.white54)));

                    final ranking = snapshot.data!;
                    final metrica = desafioDoc['metric'];
                    final sufixo = metrica == 'weight' ? 'kg' : '%';

                    return ListView.builder(
                      itemCount: ranking.length,
                      itemBuilder: (context, index) {
                        final atleta = ranking[index];
                        final delta = atleta['delta'] as double;
                        
                        String progressoStr;
                        Color corDelta = Colors.white54;

                        if (delta < 0) {
                          progressoStr = "${delta.toStringAsFixed(1)} $sufixo";
                          corDelta = AppColors.success; 
                        } else if (delta > 0) {
                          progressoStr = "+${delta.toStringAsFixed(1)} $sufixo";
                          corDelta = AppColors.error; 
                        } else {
                          progressoStr = "0.0 $sufixo";
                        }

                        Widget posicao;
                        if (index == 0) posicao = const Icon(Icons.workspace_premium, color: Colors.amber, size: 28);
                        else if (index == 1) posicao = const Icon(Icons.workspace_premium, color: Colors.grey, size: 28);
                        else if (index == 2) posicao = const Icon(Icons.workspace_premium, color: Colors.brown, size: 28);
                        else posicao = Text("${index + 1}º", style: const TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.bold));

                        return Card(
                          color: AppColors.surface,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16), 
                            side: BorderSide(color: index == 0 ? Colors.amber.withOpacity(0.5) : Colors.transparent)
                          ),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 30, child: Center(child: posicao)),
                                const SizedBox(width: 8),
                                UserAvatar(photoUrl: atleta['photoUrl'], name: atleta['name'], radius: 18),
                              ],
                            ),
                            title: Text(atleta['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: corDelta.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: corDelta.withOpacity(0.5))),
                              child: Text(progressoStr, style: TextStyle(color: corDelta, fontWeight: FontWeight.bold, fontSize: 14)),
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
    );
  }

  Future<List<Map<String, dynamic>>> _calcularPlacar(DocumentSnapshot desafioDoc) async {
    final data = desafioDoc.data() as Map<String, dynamic>;
    final metrica = data['metric'];
    final chaveBanco = metrica == 'weight' ? 'peso' : metrica; 
    final participantes = data['participants'] as Map<String, dynamic>;

    List<Map<String, dynamic>> ranking = [];

    for (var uid in data['participantIds']) {
      var pData = participantes[uid];
      if (pData['status'] != 'accepted') continue;

      double startVal = (pData['startValue'] ?? 0.0).toDouble();
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      double currentVal = (userDoc.data()?[chaveBanco] ?? 0.0).toDouble();

      double delta = currentVal - startVal;

      ranking.add({
        'uid': uid,
        'name': pData['name'],
        'photoUrl': pData['photoUrl'],
        'delta': delta,
      });
    }

    ranking.sort((a, b) => a['delta'].compareTo(b['delta']));
    return ranking;
  }

  // ==========================================
  // ABA: MEUS AMIGOS
  // ==========================================
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
            final data = minhasAmizades[index].data() as Map<String, dynamic>;
            final souEu = data['requesterId'] == user!.uid;
            
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: UserAvatar(photoUrl: souEu ? data['receiverPhoto'] : data['requesterPhoto'], name: souEu ? data['receiverName'] : data['requesterName'], radius: 20),
                title: Text(souEu ? data['receiverName'] : data['requesterName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // MODAL CRIAR DUELO 
  // ==========================================
  void _abrirModalCriarDueloEmGrupo() {
    String metricaSelecionada = 'bodyFatPercentage';
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
                        double meuStartVal = (meuDoc.data()?[chaveBanco] ?? 0.0).toDouble();

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
                        });

                        // 🔔 DISPARA NOTIFICAÇÕES PARA TODOS OS CONVIDADOS DO GRUPO
                        String metricaLabel = metricaSelecionada == 'weight' ? 'Perda de Peso' : '% de Gordura';
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

  // ==========================================
  // ABA: BUSCAR 
  // ==========================================
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

  // ==========================================
  // ABA: CONVITES 
  // ==========================================
  Widget _buildConvitesAba() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('friendships').where('receiverId', isEqualTo: user!.uid).where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum pedido de amizade pendente.", style: TextStyle(color: Colors.white54)));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
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
}