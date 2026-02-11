import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart'; // Importe suas cores
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
    Future.microtask(() {
      if (mounted) {
        context.read<TarefaController>().iniciarEscuta();
      }
    });
  }

  void _adicionarTarefaSegura(BuildContext context, TarefaController controller) {
    final texto = _taskController.text.trim();
    if (texto.isEmpty) return;

    FocusScope.of(context).unfocus();
    controller.adicionar(texto);
    _taskController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TarefaController>();

    // Ordenação: Pendentes primeiro, depois Concluídas
    final pendentes = controller.tarefas.where((t) => !t.concluida).toList();
    final concluidas = controller.tarefas.where((t) => t.concluida).toList();

    return Scaffold(
      backgroundColor: AppColors.background, // Fundo Roxo Escuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Minhas Metas", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              "Foco no resultado! 🚀",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppColors.textSub),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- ÁREA DE INPUT (Estilizada Dark) ---
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surface, // Fundo levemente mais claro que o fundo da tela
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Colors.white), // Texto Branco
                    decoration: InputDecoration(
                      hintText: "Nova meta...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black12, // Fundo do input bem sutil
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.flag_outlined, color: AppColors.secondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _adicionarTarefaSegura(context, controller),
                  ),
                ),
                const SizedBox(width: 10),
                
                // Botão "ADICIONAR" visível e intuitivo
                ElevatedButton(
                  onPressed: () => _adicionarTarefaSegura(context, controller),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary, // Neon
                    foregroundColor: Colors.black, // Texto Preto
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  child: const Text("ADICIONAR", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // --- LISTA DE TAREFAS ---
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.secondary))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    children: [
                      // Pendentes
                      if (pendentes.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 4),
                          child: Text("PENDENTES", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSub, fontSize: 12)),
                        ),
                        ...pendentes.map((t) => _buildTaskCard(context, t, controller)),
                        const SizedBox(height: 20),
                      ],

                      // Concluídas
                      if (concluidas.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10, left: 4),
                          child: Text("CONCLUÍDAS", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 12)),
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
                                Icon(Icons.check_circle_outline, size: 60, color: Colors.white10),
                                SizedBox(height: 10),
                                Text("Nenhuma meta definida.", style: TextStyle(color: Colors.white54)),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        controller.remover(tarefa.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Meta removida"),
            backgroundColor: AppColors.surface,
            action: SnackBarAction(
              label: "DESFAZER",
              textColor: AppColors.secondary,
              onPressed: () => controller.desfazerExclusao(tarefa),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface, // Card Escuro
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tarefa.concluida ? AppColors.secondary.withOpacity(0.3) : Colors.transparent,
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Checkbox(
            value: tarefa.concluida,
            activeColor: AppColors.secondary, // Neon quando marcado
            checkColor: Colors.black,
            shape: const CircleBorder(),
            side: const BorderSide(color: Colors.white54),
            onChanged: (_) => controller.alternarConclusao(tarefa),
          ),
          title: Text(
            tarefa.titulo,
            style: TextStyle(
              fontSize: 16,
              // Texto Branco (Ativo) ou Cinza/Riscado (Concluído)
              decoration: tarefa.concluida ? TextDecoration.lineThrough : null,
              color: tarefa.concluida ? Colors.white38 : Colors.white,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white30),
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
        backgroundColor: AppColors.surface, // Fundo escuro do diálogo
        title: const Text("Editar Tarefa", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textoController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.secondary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () {
              if (textoController.text.trim().isNotEmpty) {
                controller.atualizarTitulo(tarefa, textoController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}