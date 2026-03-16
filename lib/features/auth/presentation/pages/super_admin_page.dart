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
                  subtitle: Text("R\$ ${preco.toStringAsFixed(2)} • ${(data['tags'] as List?)?.join(', ') ?? ''}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- NOVO BOTÃO DE EDITAR ---
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent), 
                        onPressed: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => SystemTemplateBuilderScreen(
                                templateId: doc.id, 
                                templateData: data, // Passamos os dados para preencher a tela
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
// CONSTRUTOR DA LOJA (Agora funciona para Criar E Editar)
// ============================================================================
class SystemTemplateBuilderScreen extends StatefulWidget {
  final String? templateId; // Se vier preenchido, sabemos que é modo Edição
  final Map<String, dynamic>? templateData; 

  const SystemTemplateBuilderScreen({super.key, this.templateId, this.templateData});

  @override
  State<SystemTemplateBuilderScreen> createState() => _SystemTemplateBuilderScreenState();
}

class _SystemTemplateBuilderScreenState extends State<SystemTemplateBuilderScreen> {
  final TextEditingController _nomeTemplateController = TextEditingController();
  final TextEditingController _precoController = TextEditingController(text: "0.00"); 
  final List<WorkoutExercise> _exerciciosDoTemplate = [];
  
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
    // Se for modo de edição, carregamos todos os dados nos campos!
    if (_isEditing && widget.templateData != null) {
      _nomeTemplateController.text = widget.templateData!['nome'] ?? '';
      _precoController.text = (widget.templateData!['preco'] ?? 0.0).toStringAsFixed(2);
      
      final tagsSalvas = widget.templateData!['tags'] as List<dynamic>? ?? [];
      _tagsSelecionadas.addAll(tagsSalvas.map((t) => t.toString()));

      final exerciciosSalvos = widget.templateData!['exercicios'] as List<dynamic>? ?? [];
      _exerciciosDoTemplate.addAll(
        exerciciosSalvos.map((e) => WorkoutExercise.fromMap(e as Map<String, dynamic>))
      );
    }
  }

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
                _abrirCatalogoExercicios();
              }
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _abrirCatalogoExercicios() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Catálogo de Exercícios", style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.redAccent, 
                child: Icon(Icons.add, color: Colors.white)
              ),
              title: const Text("CRIAR NOVO EXERCÍCIO", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text("Adicionar um exercício inédito ao banco global", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context); 
                _criarExercicioGlobalDialog(); 
              },
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('exercises').orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                  final docs = snapshot.data!.docs;
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.fitness_center, color: Colors.white54),
                        title: Text(data['nome'] ?? '', style: const TextStyle(color: Colors.white)),
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
                _exerciciosDoTemplate.add(WorkoutExercise(id: DateTime.now().millisecondsSinceEpoch.toString(), nome: dadosExercicio['nome'], series: seriesCtrl.text, repeticoes: repsCtrl.text, videoUrl: dadosExercicio['videoUrl']));
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
    if (_nomeTemplateController.text.trim().isEmpty || _exerciciosDoTemplate.isEmpty) return;

    try {
      final double preco = double.tryParse(_precoController.text.replaceAll(',', '.')) ?? 0.0;

      final dataMap = {
        'personalId': 'SYSTEM_ADMIN', 
        'nome': _nomeTemplateController.text.trim(),
        'exercicios': _exerciciosDoTemplate.map((e) => e.toMap()).toList(),
        'tags': _tagsSelecionadas, 
        'preco': preco, 
        'isPremium': true, 
        // Atualiza a data se for novo, ou mantém a mesma se for edição (para não bagunçar a ordem)
        if (!_isEditing) 'timestamp': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        // Atualiza o documento existente
        await FirebaseFirestore.instance.collection('workout_templates').doc(widget.templateId).update(dataMap);
      } else {
        // Cria um documento novo
        await FirebaseFirestore.instance.collection('workout_templates').add(dataMap);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.add, color: Colors.redAccent), label: const Text("Adicionar Exercício", style: TextStyle(color: Colors.redAccent, fontSize: 16)), onPressed: _abrirCatalogoExercicios))),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _exerciciosDoTemplate.length,
              itemBuilder: (context, index) {
                final ex = _exerciciosDoTemplate[index];
                return Card(color: AppColors.surface, margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(ex.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text("${ex.series}x ${ex.repeticoes}", style: const TextStyle(color: Colors.redAccent)), trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => setState(() => _exerciciosDoTemplate.removeAt(index)))));
              },
            ),
          ),
        ],
      ),
    );
  }
}