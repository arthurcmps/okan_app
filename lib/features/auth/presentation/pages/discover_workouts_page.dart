import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; 
import '../../data/models/workout_plans_model.dart';

class DiscoverWorkoutsPage extends StatefulWidget {
  const DiscoverWorkoutsPage({super.key});

  @override
  State<DiscoverWorkoutsPage> createState() => _DiscoverWorkoutsPageState();
}

class _DiscoverWorkoutsPageState extends State<DiscoverWorkoutsPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<String> _userTags = [];

  @override
  void initState() {
    super.initState();
    _analisarPerfilAluno();
  }

  Future<void> _analisarPerfilAluno() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        List<String> tags = [];

        if (data['check_hipertrofia'] == true) tags.add('Hipertrofia');
        if (data['check_emagrecimento'] == true) tags.add('Emagrecimento');
        if (data['check_condicionamento'] == true) tags.add('Condicionamento');
        if (data['check_iniciante'] == true) tags.add('Iniciante');
        if (data['check_intermediário'] == true) tags.add('Intermediário'); 
        if (data['check_avançado'] == true) tags.add('Avançado');
        if (data['check_casa'] == true) tags.add('Casa');
        if (data['check_academia'] == true) tags.add('Academia');
        
        setState(() {
          _userTags = tags;
        });
      }
    } catch (e) {
      debugPrint("Erro ao ler anamnese: $e");
    }
  }

  int _calcularScoreDeMatch(List<dynamic> templateTags) {
    int score = 0;
    for (var tag in templateTags) {
      if (_userTags.contains(tag.toString())) score += 10; 
    }
    return score;
  }

  // ==============================================================
  // LÓGICA DE AQUISIÇÃO E APLICAÇÃO
  // ==============================================================

  // 1. O Aluno clica em Comprar/Adicionar na Loja
  void _processarAquisicao(String templateId, Map<String, dynamic> treinoData) {
    final double preco = (treinoData['preco'] ?? 0.0).toDouble();

    if (preco <= 0) {
      _registrarCompraNoPerfil(templateId); // É grátis, pega direto
    } else {
      // Simulação de Pagamento
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text("Pagamento (Em Breve)", style: TextStyle(color: AppColors.primary)),
          content: Text("Aqui o aluno fará o PIX de R\$ ${preco.toStringAsFixed(2)}. Após o pagamento, o treino vai para a biblioteca dele.", style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(context);
                _registrarCompraNoPerfil(templateId);
              },
              child: const Text("Simular Pagamento Aprovado", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  // 2. Salva o ID do treino no perfil do aluno
  Future<void> _registrarCompraNoPerfil(String templateId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'purchased_templates': FieldValue.arrayUnion([templateId])
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino adicionado à sua Biblioteca! 🎉"), backgroundColor: AppColors.success));
      }
    } catch (e) {
      debugPrint("Erro ao salvar compra: $e");
    }
  }

  // 3. O Aluno escolhe os dias para treinar (Funciona tanto após comprar quanto na aba Meus Treinos)
  void _escolherDiasParaOTreino(Map<String, dynamic> treinoData) {
    final List<String> diasSemana = ['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo'];
    final List<String> diasNomes = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    List<String> diasSelecionados = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text("Aplicar na Semana", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Em quais dias da semana você deseja fazer esta ficha?", style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: List.generate(diasSemana.length, (index) {
                      final diaKey = diasSemana[index];
                      final isSelected = diasSelecionados.contains(diaKey);
                      return FilterChip(
                        label: Text(diasNomes[index]),
                        selected: isSelected,
                        selectedColor: AppColors.secondary,
                        backgroundColor: Colors.black26,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white70),
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) diasSelecionados.add(diaKey);
                            else diasSelecionados.remove(diaKey);
                          });
                        },
                      );
                    }),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: diasSelecionados.isEmpty ? null : () {
                    Navigator.pop(context);
                    _inserirTreinoNaFicha(treinoData, diasSelecionados);
                  },
                  child: const Text("Aplicar Ficha", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                )
              ],
            );
          }
        );
      }
    );
  }

  // 4. Copia os exercícios para o WeeklyPlan
  Future<void> _inserirTreinoNaFicha(Map<String, dynamic> treinoData, List<String> diasSelecionados) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)));

    try {
      final List exerciciosRaw = treinoData['exercicios'] ?? [];
      List<Map<String, dynamic>> exerciciosMapeados = exerciciosRaw.map((e) {
        final ex = WorkoutExercise.fromMap(e as Map<String, dynamic>);
        ex.id = DateTime.now().microsecondsSinceEpoch.toString() + ex.nome.hashCode.toString();
        ex.concluido = false;
        return ex.toMap();
      }).toList();

      final docRef = FirebaseFirestore.instance.collection('workout_plans').doc(currentUserId);
      final docSnap = await docRef.get();
      Map<String, dynamic> planoAtual = docSnap.exists ? docSnap.data()! : {};

      for (var dia in diasSelecionados) {
        List<dynamic> exerciciosDoDia = planoAtual[dia] ?? [];
        exerciciosDoDia.addAll(exerciciosMapeados);
        planoAtual[dia] = exerciciosDoDia;
      }

      await docRef.set(planoAtual, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context); // Fecha loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino aplicado com sucesso à sua semana! 💪"), backgroundColor: AppColors.primary));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao aplicar: $e")));
      }
    }
  }

  // ==============================================================
  // UI: DETALHES DO TREINO (Muda o botão se ele já comprou)
  // ==============================================================
  void _abrirDetalhesDoTreino(String templateId, Map<String, dynamic> treinoData, int matchScore, bool jaAdquirido) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text(treinoData['nome'] ?? 'Treino Premium', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            if (matchScore > 0 && !jaAdquirido)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary)),
                child: Text("🔥 ${matchScore >= 20 ? 'Combinação Perfeita' : 'Recomendado para você'}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              
            const SizedBox(height: 24),
            const Text("O que inclui:", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: (treinoData['exercicios'] as List).length,
                itemBuilder: (context, index) {
                  final ex = treinoData['exercicios'][index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle, color: AppColors.secondary),
                    title: Text(ex['nome'], style: const TextStyle(color: Colors.white)),
                    subtitle: Text("${ex['series']}x ${ex['repeticoes']}", style: const TextStyle(color: Colors.white54)),
                  );
                },
              ),
            ),
            
            // BOTÃO DINÂMICO: COMPRAR vs APLICAR NA SEMANA
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: jaAdquirido ? AppColors.secondary : AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context); // Fecha bottom sheet
                  if (jaAdquirido) {
                    _escolherDiasParaOTreino(treinoData);
                  } else {
                    _processarAquisicao(templateId, treinoData);
                  }
                },
                child: Text(
                  jaAdquirido 
                    ? "APLICAR NA MINHA SEMANA" 
                    : ((treinoData['preco'] ?? 0) > 0 ? "COMPRAR POR R\$ ${treinoData['preco'].toStringAsFixed(2)}" : "ADICIONAR GRÁTIS"),
                  style: TextStyle(color: jaAdquirido ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // UI: CONSTRUÇÃO DAS ABAS (LOJA E BIBLIOTECA)
  // ==============================================================
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text("Loja de Treinos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white54,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Explorar Loja", icon: Icon(Icons.storefront)),
              Tab(text: "Meus Treinos", icon: Icon(Icons.inventory_2_outlined)),
            ],
          ),
        ),
        // O Stream principal escuta o Perfil do Usuário para saber o que ele já comprou em tempo real
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            final List<String> meusTreinosIds = List<String>.from(userData['purchased_templates'] ?? []);

            // Stream secundário busca todos os treinos da loja
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('workout_templates').where('isPremium', isEqualTo: true).snapshots(),
              builder: (context, templatesSnapshot) {
                if (templatesSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allTemplates = templatesSnapshot.data?.docs ?? [];

                // Separa os treinos entre "Loja" (não tenho) e "Meus" (já tenho)
                final lojaTemplates = allTemplates.where((doc) => !meusTreinosIds.contains(doc.id)).toList();
                final meusTemplates = allTemplates.where((doc) => meusTreinosIds.contains(doc.id)).toList();

                return TabBarView(
                  children: [
                    _buildListaTreinos(lojaTemplates, true), // Aba Loja
                    _buildListaTreinos(meusTemplates, false), // Aba Meus Treinos
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildListaTreinos(List<QueryDocumentSnapshot> docs, bool isLoja) {
    if (docs.isEmpty) {
      return Center(
        child: Text(
          isLoja ? "Nenhum treino novo disponível no momento." : "Sua biblioteca está vazia.\\nAdquira treinos na loja!", 
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 16)
        )
      );
    }

    var treinos = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final tagsDoTreino = data['tags'] as List<dynamic>? ?? [];
      final score = isLoja ? _calcularScoreDeMatch(tagsDoTreino) : 0; // Só calcula match na loja
      return {'docId': doc.id, 'data': data, 'score': score};
    }).toList();

    if (isLoja) treinos.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: treinos.length,
      itemBuilder: (context, index) {
        final treino = treinos[index];
        final templateId = treino['docId'] as String;
        final data = treino['data'] as Map<String, dynamic>;
        final score = treino['score'] as int;
        final preco = data['preco'] ?? 0.0;
        final exercicios = data['exercicios'] as List<dynamic>? ?? [];

        return GestureDetector(
          onTap: () => _abrirDetalhesDoTreino(templateId, data, score, !isLoja),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: score > 0 && isLoja ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1) : null,
              boxShadow: score >= 20 && isLoja ? [BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, spreadRadius: -5)] : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isLoja && score > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                        child: const Text("MATCH ALTO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                      )
                    else if (!isLoja)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.secondary)),
                        child: const Text("ADQUIRIDO", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 10)),
                      )
                    else
                      const SizedBox.shrink(),
                    
                    Text(
                      isLoja ? (preco > 0 ? "R\$ ${preco.toStringAsFixed(2)}" : "GRÁTIS") : "PRONTO PARA USO", 
                      style: TextStyle(color: isLoja ? AppColors.secondary : Colors.white54, fontWeight: FontWeight.bold, fontSize: isLoja ? 18 : 12)
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(data['nome'] ?? 'Sem Nome', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("${exercicios.length} exercícios", style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ),
        );
      },
    );
  }
}