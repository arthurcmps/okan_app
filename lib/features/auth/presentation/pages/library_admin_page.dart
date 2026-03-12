import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; 
import '../../data/models/workout_plans_model.dart'; // Necessário para a classe WorkoutExercise

class LibraryAdminPage extends StatefulWidget {
  const LibraryAdminPage({super.key});

  @override
  State<LibraryAdminPage> createState() => _LibraryAdminPageState();
}

class _LibraryAdminPageState extends State<LibraryAdminPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  final TextEditingController _grupoController = TextEditingController();

  final CollectionReference _exercisesCollection = FirebaseFirestore.instance.collection('exercises'); 

  @override
  void initState() {
    super.initState();
    // Controlador para as 2 abas (Exercícios e Templates)
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Atualiza a interface (especialmente o botão +) ao trocar de aba
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // =========================================================
  // LÓGICA DA ABA 1: EXERCÍCIOS INDIVIDUAIS
  // =========================================================
  
  void _mostrarDialogoExercicio({DocumentSnapshot? doc}) {
    final bool isEditando = doc != null;

    if (isEditando) {
      _nomeController.text = doc['nome'] ?? '';
      final data = doc.data() as Map<String, dynamic>;
      _videoController.text = data['videoUrl'] ?? data['video'] ?? '';
      _grupoController.text = data['grupo'] ?? '';
    } else {
      _nomeController.clear();
      _videoController.clear();
      _grupoController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface, 
          title: Text(
            isEditando ? "Editar Exercício" : "Novo Exercício", 
            style: const TextStyle(color: Colors.white)
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogInput(_nomeController, "Nome do Exercício"),
                const SizedBox(height: 12),
                _buildDialogInput(_grupoController, "Grupo Muscular"),
                const SizedBox(height: 12),
                _buildDialogInput(_videoController, "Link do Vídeo (YouTube)", icone: Icons.link),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: () async {
                if (_nomeController.text.isEmpty) return;
                
                final data = {
                  'nome': _nomeController.text.trim(),
                  'grupo': _grupoController.text.trim(),
                  'videoUrl': _videoController.text.trim(),
                  'criadoEm': FieldValue.serverTimestamp(),
                };

                try {
                  if (isEditando) {
                    await _exercisesCollection.doc(doc.id).update(data);
                  } else {
                    await _exercisesCollection.add(data);
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: AppColors.error));
                }
              },
              child: const Text("Salvar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String label, {IconData? icone}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: icone != null ? Icon(icone, color: Colors.white54) : null,
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  void _confirmarDeletarDocumento(String id, String titulo, String collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Excluir Item?", style: TextStyle(color: Colors.white)),
        content: Text("Tem certeza que deseja apagar '$titulo'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseFirestore.instance.collection(collection).doc(id).delete();
              Navigator.pop(context);
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
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Gerenciar Biblioteca", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          labelColor: AppColors.secondary,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center), text: "Exercícios"),
            Tab(icon: Icon(Icons.library_books), text: "Templates"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ABA 1: LISTA DE EXERCÍCIOS
          _buildAbaExercicios(),
          
          // ABA 2: LISTA DE TEMPLATES
          _buildAbaTemplates(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (_tabController.index == 0) {
            _mostrarDialogoExercicio(); // Abre dialog de Exercício
          } else {
            // Abre Tela de Criar Template
            Navigator.push(context, MaterialPageRoute(builder: (context) => const TemplateBuilderScreen()));
          }
        },
        child: Icon(_tabController.index == 0 ? Icons.add : Icons.post_add, color: Colors.black),
      ),
    );
  }

  // --- WIDGET DA ABA DE EXERCÍCIOS ---
  Widget _buildAbaExercicios() {
    return StreamBuilder<QuerySnapshot>(
      stream: _exercisesCollection.orderBy('nome').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nenhum exercício cadastrado.", style: TextStyle(color: Colors.white54)));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.secondary.withOpacity(0.2), child: const Icon(Icons.fitness_center, color: AppColors.secondary)),
                title: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(data['grupo'] ?? 'Geral', style: const TextStyle(color: Colors.white54)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.white70), onPressed: () => _mostrarDialogoExercicio(doc: doc)),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmarDeletarDocumento(doc.id, data['nome'] ?? '', 'exercises')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- WIDGET DA ABA DE TEMPLATES ---
  Widget _buildAbaTemplates() {
    final meuId = FirebaseAuth.instance.currentUser?.uid;
    if (meuId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('workout_templates')
          .where('personalId', isEqualTo: meuId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Você ainda não criou nenhum template.", style: TextStyle(color: Colors.white54)));
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final listaEx = data['exercicios'] as List<dynamic>? ?? [];
            
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.2), child: const Icon(Icons.library_books, color: AppColors.primary)),
                title: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text("${listaEx.length} exercícios guardados", style: const TextStyle(color: Colors.white54)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                  onPressed: () => _confirmarDeletarDocumento(doc.id, data['nome'] ?? '', 'workout_templates')
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// NOVA TELA EXCLUSIVA: CONSTRUTOR DE TEMPLATES (TEMPLATE BUILDER)
// ============================================================================
class TemplateBuilderScreen extends StatefulWidget {
  const TemplateBuilderScreen({super.key});

  @override
  State<TemplateBuilderScreen> createState() => _TemplateBuilderScreenState();
}

class _TemplateBuilderScreenState extends State<TemplateBuilderScreen> {
  final TextEditingController _nomeTemplateController = TextEditingController();
  final List<WorkoutExercise> _exerciciosDoTemplate = [];

  // Puxa o exercício do catálogo e pede séries e repetições
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
              child: Text("Escolha um Exercício", style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('exercises').orderBy('nome').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;
                  
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.fitness_center, color: AppColors.secondary),
                        title: Text(data['nome'] ?? '', style: const TextStyle(color: Colors.white)),
                        trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
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
            Expanded(
              child: TextField(
                controller: seriesCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Séries", labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: repsCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: "Reps", labelStyle: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              setState(() {
                _exerciciosDoTemplate.add(
                  WorkoutExercise(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nome: dadosExercicio['nome'],
                    series: seriesCtrl.text,
                    repeticoes: repsCtrl.text,
                    videoUrl: dadosExercicio['videoUrl'],
                  )
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Adicionar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _salvarTemplateFinal() async {
    if (_nomeTemplateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dê um nome ao template!"), backgroundColor: AppColors.error));
      return;
    }
    if (_exerciciosDoTemplate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adicione ao menos um exercício!"), backgroundColor: AppColors.error));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('workout_templates').add({
        'personalId': FirebaseAuth.instance.currentUser!.uid,
        'nome': _nomeTemplateController.text.trim(),
        'exercicios': _exerciciosDoTemplate.map((e) => e.toMap()).toList(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pop(context); // Fecha o construtor e volta para a Biblioteca
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Template salvo com sucesso!"), backgroundColor: AppColors.success));
      }
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
        foregroundColor: Colors.white,
        title: const Text("Criar Novo Template", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            onPressed: _salvarTemplateFinal,
            tooltip: "Salvar Template",
          )
        ],
      ),
      body: Column(
        children: [
          // Campo para o nome do Template
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nomeTemplateController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Nome do Treino (Ex: Ficha A - Peito)",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Botão para adicionar mais exercícios
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add, color: AppColors.primary),
                label: const Text("Adicionar Exercício", style: TextStyle(color: AppColors.primary, fontSize: 16)),
                onPressed: _abrirCatalogoExercicios,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lista de exercícios já adicionados
          Expanded(
            child: _exerciciosDoTemplate.isEmpty
                ? const Center(child: Text("Ficha vazia. Adicione os exercícios acima.", style: TextStyle(color: Colors.white30)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _exerciciosDoTemplate.length,
                    itemBuilder: (context, index) {
                      final ex = _exerciciosDoTemplate[index];
                      return Card(
                        color: AppColors.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(ex.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text("${ex.series} séries de ${ex.repeticoes}", style: const TextStyle(color: AppColors.secondary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            onPressed: () {
                              setState(() {
                                _exerciciosDoTemplate.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}