import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/tarefa_model.dart';
import '../controllers/tarefa_controller.dart';

class TarefasPage extends StatefulWidget {
  const TarefasPage({super.key});

  @override
  State<TarefasPage> createState() => _TarefasPageState();
}

class _TarefasPageState extends State<TarefasPage> {
  final TextEditingController _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Garante que carregamos as tarefas DO USUÁRIO ATUAL ao abrir a tela
    Future.microtask(() {
      if (mounted) {
        context.read<TarefaController>().iniciarEscuta();
      }
    });
  }

  // --- FUNÇÃO SEGURA PARA ADICIONAR ---
  void _adicionarTarefaSegura(BuildContext context, TarefaController controller) {
    final texto = _taskController.text.trim();
    if (texto.isEmpty) return;

    // 1. Fecha o teclado PRIMEIRO para evitar conflito de UI
    FocusScope.of(context).unfocus();

    // 2. Chama o controller
    controller.adicionar(texto);

    // 3. Limpa o campo
    _taskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TarefaController>();

    final pendentes = controller.tarefas.where((t) => !t.concluida).toList();
    final concluidas = controller.tarefas.where((t) => t.concluida).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Minhas Metas"),
            Text(
              "Foco no resultado! 🚀",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- ÁREA DE INPUT ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Nova meta ou tarefa...",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.check_circle_outline),
                    ),
                    onSubmitted: (_) => _adicionarTarefaSegura(context, controller),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  backgroundColor: Colors.blueAccent,
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _adicionarTarefaSegura(context, controller),
                ),
              ],
            ),
          ),

          // --- LISTA DE TAREFAS ---
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // Pendentes
                      if (pendentes.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text("PENDENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        ...pendentes.map((t) => _buildTaskCard(context, t, controller)),
                      ],

                      // Concluídas
                      if (concluidas.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text("CONCLUÍDAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                        ...concluidas.map((t) => _buildTaskCard(context, t, controller)),
                      ],

                      // Vazio
                      if (controller.tarefas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.list_alt, size: 60, color: Colors.black12),
                                SizedBox(height: 10),
                                Text("Nenhuma meta ainda.", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Tarefa tarefa, TarefaController controller) {
    return Dismissible(
      key: Key(tarefa.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        controller.remover(tarefa.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Tarefa removida"),
            action: SnackBarAction(
              label: "DESFAZER",
              onPressed: () => controller.desfazerExclusao(tarefa),
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Checkbox(
            value: tarefa.concluida,
            activeColor: Colors.green,
            shape: const CircleBorder(),
            onChanged: (_) => controller.alternarConclusao(tarefa),
          ),
          title: Text(
            tarefa.titulo,
            style: TextStyle(
              fontSize: 16,
              decoration: tarefa.concluida ? TextDecoration.lineThrough : null,
              color: tarefa.concluida ? Colors.grey : Colors.black87,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.grey),
            onPressed: () => _mostrarDialogoEditar(context, tarefa, controller),
          ),
        ),
      ),
    );
  }

  void _mostrarDialogoEditar(BuildContext context, Tarefa tarefa, TarefaController controller) {
    final textoController = TextEditingController(text: tarefa.titulo);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Tarefa"),
        content: TextField(
          controller: textoController,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              if (textoController.text.trim().isNotEmpty) {
                controller.atualizarTitulo(tarefa, textoController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }
}