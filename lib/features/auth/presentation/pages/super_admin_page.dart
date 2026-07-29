import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/workout_plans_model.dart';

class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key});

  void _deletarTemplate(BuildContext context, String id, String nome) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Excluir Produto?", style: TextStyle(color: Colors.white)),
        content: Text("Tem certeza que deseja remover o treino '$nome' da Loja Oficial?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('workout_templates').doc(id).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Excluir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.redAccent.withOpacity(0.1), 
        foregroundColor: Colors.redAccent,
        title: const Text("⚙️ SUPER ADMIN: LOJA", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('workout_templates')
            .where('personalId', isEqualTo: 'SYSTEM_ADMIN')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Nenhum produto na loja do sistema.", style: TextStyle(color: Colors.white54)));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final preco = data['preco'] ?? 0.0;
              
              // Verifica quantidade de fichas no template
              final fichasMap = data['fichas'] as Map<String, dynamic>?;
              final qtdFichas = fichasMap?.keys.length ?? (data['exercicios'] != null ? 1 : 0);
              
              return Card(
                color: AppColors.surface,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.redAccent, width: 0.5)
                ),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.store, color: Colors.white)),
                  title: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text(
                    "R\$ ${preco.toStringAsFixed(2)} • $qtdFichas Ficha(s)\n${(data['tags'] as List?)?.join(', ') ?? ''}", 
                    style: const TextStyle(color: Colors.white54, fontSize: 12)
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent), 
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => SystemTemplateBuilderScreen(
                                templateId: doc.id, 
                                templateData: data,
                              )
                            )
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                        onPressed: () => _deletarTemplate(context, doc.id, data['nome']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemTemplateBuilderScreen())),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NOVO PRODUTO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ============================================================================
// CONSTRUTOR DA LOJA (Com Fichas Múltiplas e Filtros de Exercícios)
// ============================================================================
class SystemTemplateBuilderScreen extends StatefulWidget {
  final String? templateId;
  final Map<String, dynamic>? templateData; 

  const SystemTemplateBuilderScreen({super.key, this.templateId, this.templateData});

  @override
  State<SystemTemplateBuilderScreen> createState() => _SystemTemplateBuilderScreenState();
}

class _SystemTemplateBuilderScreenState extends State<SystemTemplateBuilderScreen> {
  final TextEditingController _nomeTemplateController = TextEditingController();
  final TextEditingController _precoController = TextEditingController(text: "0.00"); 
  
  // MAPA DE FICHAS: Ex => {'A': [WorkoutExercise, ...], 'B': [...]}
  final Map<String, List<WorkoutExercise>> _fichasDoTemplate = {'A': []};
  String _fichaAtiva = 'A';

  final List<String> _tagsDisponiveis = [
    'Hipertrofia', 'Emagrecimento', 'Condicionamento',
    'Iniciante', 'Intermediário', 'Avançado',
    'Casa', 'Academia', 'Sem Impacto'
  ];
  final List<String> _tagsSelecionadas = [];

  bool get _isEditing => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.templateData != null) {
      _nomeTemplateController.text = widget.templateData!['nome'] ?? '';
      _precoController.text = (widget.templateData!['preco'] ?? 0.0).toStringAsFixed(2);
      
      final tagsSalvas = widget.templateData!['tags'] as List<dynamic>? ?? [];
      _tagsSelecionadas.addAll(tagsSalvas.map((t) => t.toString()));

      // Lê estrutura de 'fichas' (ou converte treino antigo 'exercicios' em Ficha A)
      final fichasMap = widget.templateData!['fichas'] as Map<String, dynamic>?;
      if (fichasMap != null && fichasMap.isNotEmpty) {
        _fichasDoTemplate.clear();
        fichasMap.forEach((letra, listaRaw) {
          final listEx = (listaRaw as List<dynamic>)
              .map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>))
              .toList();
          _fichasDoTemplate[letra] = listEx;
        });
        _fichaAtiva = _fichasDoTemplate.keys.first;
      } else {
        final exSalvos = widget.templateData!['exercicios'] as List<dynamic>? ?? [];
        _fichasDoTemplate['A'] = exSalvos.map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>)).toList();
      }
    }
  }

  // --- CONTROLE DAS ABAS DE FICHAS ---
  void _adicionarFicha() {
    const alfabeto = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    for (int i = 0; i < alfabeto.length; i++) {
      String letra = alfabeto[i];
      if (!_fichasDoTemplate.containsKey(letra)) {
        setState(() {
          _fichasDoTemplate[letra] = [];
          _fichaAtiva = letra;
        });
        break;
      }
    }
  }

  void _removerFicha(String letra) {
    if (_fichasDoTemplate.length <= 1) return;
    setState(() {
      _fichasDoTemplate.remove(letra);
      _fichaAtiva = _fichasDoTemplate.keys.first;
    });
  }

  // --- CRIAR NOVO EXERCÍCIO GLOBAL NO BANCO ---
  void _criarExercicioGlobalDialog() {
    final nomeCtrl = TextEditingController();
    final grupoCtrl = TextEditingController();
    final videoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Novo Exercício Global", style: TextStyle(color: Colors.redAccent)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl, 
                style: const TextStyle(color: Colors.white), 
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: "Nome do Exercício", labelStyle: TextStyle(color: Colors.white54))
              ),
              const SizedBox(height: 10),
              TextField(
                controller: grupoCtrl, 
                style: const TextStyle(color: Colors.white), 
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: "Grupo Muscular (Ex: Peito)", labelStyle: TextStyle(color: Colors.white54))
              ),
              const SizedBox(height: 10),
              TextField(
                controller: videoCtrl, 
                style: const TextStyle(color: Colors.white), 
                decoration: const InputDecoration(labelText: "Link do YouTube (Opcional)", labelStyle: TextStyle(color: Colors.white54))
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (nomeCtrl.text.isEmpty) return;
              
              await FirebaseFirestore.instance.collection('exercises').add({
                'nome': nomeCtrl.text.trim(),
                'grupo': grupoCtrl.text.trim(),
                'videoUrl': videoCtrl.text.trim(),
                'criadoEm': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Exercício salvo no catálogo global!"), backgroundColor: Colors.green));
              }
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // --- CATÁLOGO COM FILTROS (BUSCA E GRUPOS MUSCULARES) ---
  void _abrirCatalogoExercicios() {
    String queryBusca = '';
    String? grupoSelecionado;

    final List<String> gruposMusculares = [
      'Peito', 'Costas', 'Pernas', 'Ombros', 'Bíceps', 'Tríceps', 'Abdômen', 'Cardio'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            builder: (context, scrollController) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Catálogo de Exercícios", style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                
                // BARRA DE BUSCA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar exercício...",
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.background,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        queryBusca = val.toLowerCase().trim();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // FILTRO POR GRUPO MUSCULAR
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text("Todos"),
                        selected: grupoSelecionado == null,
                        selectedColor: Colors.redAccent,
                        backgroundColor: Colors.black26,
                        labelStyle: TextStyle(color: grupoSelecionado == null ? Colors.white : Colors.white70, fontSize: 12),
                        onSelected: (_) => setModalState(() => grupoSelecionado = null),
                      ),
                      const SizedBox(width: 8),
                      ...gruposMusculares.map((grupo) {
                        final isSel = grupoSelecionado == grupo;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(grupo),
                            selected: isSel,
                            selectedColor: Colors.redAccent,
                            backgroundColor: Colors.black26,
                            labelStyle: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 12),
                            onSelected: (_) => setModalState(() => grupoSelecionado = isSel ? null : grupo),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.add, color: Colors.white)),
                  title: const Text("CRIAR NOVO EXERCÍCIO", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Adicionar exercício inédito ao banco", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context); 
                    _criarExercicioGlobalDialog(); 
                  },
                ),
                const Divider(color: Colors.white24),
                
                // LISTA COM A APLICAÇÃO DOS FILTROS
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('exercises').orderBy('nome').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                      
                      var docs = snapshot.data!.docs;

                      // Aplica filtro em memória por Nome e Grupo
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final nomeEx = (data['nome'] ?? '').toString().toLowerCase();
                        final grupoEx = (data['grupo'] ?? '').toString();

                        final matchBusca = queryBusca.isEmpty || nomeEx.contains(queryBusca);
                        final matchGrupo = grupoSelecionado == null || 
                                           grupoEx.toLowerCase() == grupoSelecionado!.toLowerCase();

                        return matchBusca && matchGrupo;
                      }).toList();

                      if (docs.isEmpty) {
                        return const Center(child: Text("Nenhum exercício encontrado.", style: TextStyle(color: Colors.white54)));
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          return ListTile(
                            leading: const Icon(Icons.fitness_center, color: Colors.white54),
                            title: Text(data['nome'] ?? '', style: const TextStyle(color: Colors.white)),
                            subtitle: Text(data['grupo'] ?? 'Geral', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                            trailing: const Icon(Icons.add_circle_outline, color: Colors.redAccent),
                            onTap: () {
                              Navigator.pop(context);
                              _configurarSeriesEReps(data);
                            },
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
      ),
    );
  }

  void _configurarSeriesEReps(Map<String, dynamic> dadosExercicio) {
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Séries para: ${dadosExercicio['nome']}", style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Row(
          children: [
            Expanded(child: TextField(controller: seriesCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Séries", labelStyle: TextStyle(color: Colors.white54)))),
            const SizedBox(width: 16),
            Expanded(child: TextField(controller: repsCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Reps", labelStyle: TextStyle(color: Colors.white54)))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                _fichasDoTemplate[_fichaAtiva]!.add(WorkoutExercise(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), 
                  nome: dadosExercicio['nome'], 
                  series: seriesCtrl.text, 
                  repeticoes: repsCtrl.text, 
                  videoUrl: dadosExercicio['videoUrl']
                ));
              });
              Navigator.pop(context);
            },
            child: const Text("Adicionar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _salvarTemplateFinal() async {
    // Garante que exista algum exercício
    bool temExercicios = _fichasDoTemplate.values.any((list) => list.isNotEmpty);
    if (_nomeTemplateController.text.trim().isEmpty || !temExercicios) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o nome e adicione exercícios!"), backgroundColor: AppColors.error));
      return;
    }

    try {
      final double preco = double.tryParse(_precoController.text.replaceAll(',', '.')) ?? 0.0;

      // Converte o Mapa de Objetos para o formato Firestore {A: [map, ...], B: [map, ...]}
      Map<String, dynamic> fichasGravacao = {};
      _fichasDoTemplate.forEach((letra, listaEx) {
        fichasGravacao[letra] = listaEx.map((e) => e.toMap()).toList();
      });

      final dataMap = {
        'personalId': 'SYSTEM_ADMIN', 
        'nome': _nomeTemplateController.text.trim(),
        'fichas': fichasGravacao,
        // E também salva uma cópia dos exercícios da primeira ficha em 'exercicios' para retrocompatibilidade
        'exercicios': fichasGravacao['A'] ?? [],
        'tags': _tagsSelecionadas, 
        'preco': preco, 
        'isPremium': true, 
        if (!_isEditing) 'timestamp': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        await FirebaseFirestore.instance.collection('workout_templates').doc(widget.templateId).update(dataMap);
      } else {
        await FirebaseFirestore.instance.collection('workout_templates').add(dataMap);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final exerciciosDaFicha = _fichasDoTemplate[_fichaAtiva] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.redAccent,
        title: Text(_isEditing ? "Editar Produto" : "Novo Produto", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.check_circle, size: 28), onPressed: _salvarTemplateFinal)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _nomeTemplateController, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: "Nome do Treino (Ex: Projeto Verão)", hintStyle: const TextStyle(color: Colors.white30), filled: true, fillColor: AppColors.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: _precoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: "Preço de Venda (0 = Grátis)", labelStyle: const TextStyle(color: Colors.white54), prefixText: "R\$ ", prefixStyle: const TextStyle(color: Colors.redAccent), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 16),
                const Text("Tags para Match:", style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: -8,
                  children: _tagsDisponiveis.map((tag) {
                    final isSelected = _tagsSelecionadas.contains(tag);
                    return FilterChip(
                      label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.white70)),
                      selected: isSelected, selectedColor: Colors.redAccent.withOpacity(0.8), backgroundColor: Colors.black26, checkmarkColor: Colors.white,
                      onSelected: (selected) => setState(() => selected ? _tagsSelecionadas.add(tag) : _tagsSelecionadas.remove(tag)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          
          // --- BARRA DE ABAS DAS FICHAS (A, B, C...) ---
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _fichasDoTemplate.keys.map((letra) {
                      final isAtiva = _fichaAtiva == letra;
                      return GestureDetector(
                        onTap: () => setState(() => _fichaAtiva = letra),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isAtiva ? Colors.redAccent : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Ficha $letra", style: TextStyle(color: isAtiva ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                              if (_fichasDoTemplate.length > 1 && isAtiva) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => _removerFicha(letra),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                )
                              ]
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.redAccent),
                  tooltip: "Nova Ficha",
                  onPressed: _adicionarFicha,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0), 
            child: SizedBox(
              width: double.infinity, 
              height: 48, 
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ), 
                icon: const Icon(Icons.add, color: Colors.redAccent), 
                label: Text("Adicionar Exercício (Ficha $_fichaAtiva)", style: const TextStyle(color: Colors.redAccent, fontSize: 15)), 
                onPressed: _abrirCatalogoExercicios
              )
            )
          ),
          const SizedBox(height: 12),

          // LISTA DE EXERCÍCIOS DA FICHA ATUAL
          Expanded(
            child: exerciciosDaFicha.isEmpty
                ? const Center(child: Text("Nenhum exercício na ficha selecionada.", style: TextStyle(color: Colors.white30)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: exerciciosDaFicha.length,
                    itemBuilder: (context, index) {
                      final ex = exerciciosDaFicha[index];
                      return Card(
                        color: AppColors.surface, 
                        margin: const EdgeInsets.only(bottom: 8), 
                        child: ListTile(
                          title: Text(ex.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                          subtitle: Text("${ex.series}x ${ex.repeticoes}", style: const TextStyle(color: Colors.redAccent)), 
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), 
                            onPressed: () => setState(() => _fichasDoTemplate[_fichaAtiva]!.removeAt(index))
                          )
                        )
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}