import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/tarefa_controller.dart';
import '../../data/models/tarefa_controller.dart';
import 'package:intl/intl.dart';

class TarefasPage extends StatelessWidget {
  const TarefasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<TarefaController>(context);
    
    final pendentes = controller.tarefas.where((t) => !t.concluida).toList();
    final concluidas = controller.tarefas.where((t) => t.concluida).toList();
    
    // Cálculo de progresso
    final total = controller.tarefas.length;
    final feitos = concluidas.length;
    final progresso = total == 0 ? 0.0 : feitos / total;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Minhas Tarefas", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        children: [
          // BARRA DE PROGRESSO
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Progresso Diário", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("${(progresso * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progresso,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFF2563EB),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),

          // LISTA
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (pendentes.isNotEmpty) ...[
                  _buildSectionTitle("PENDENTES"),
                  ...pendentes.map((t) => _buildTaskCard(context, t, controller)),
                ],

                if (concluidas.isNotEmpty) ...[
                  _buildSectionTitle("CONCLUÍDAS"),
                  ...concluidas.map((t) => _buildTaskCard(context, t, controller)),
                ],
                
                if (controller.tarefas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Center(child: Text("Nenhuma tarefa ainda!", style: TextStyle(color: Colors.grey))),
                  ),
                 const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nova Tarefa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _mostrarDialogo(context, controller, null),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
    );
  }

  // --- O CARD COM DESLIZE (SWIPE) ---

  Widget _buildTaskCard(BuildContext context, Tarefa tarefa, TarefaController controller) {
    // Formatador de data (Ex: 10 fev - 14:30)
    final dateFormat = DateFormat("dd MMM 'às' HH:mm", 'pt_BR');

    return Dismissible(
      key: Key(tarefa.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red[400], borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      onDismissed: (direction) {
        controller.remover(tarefa.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Meta excluída"),
            action: SnackBarAction(
              label: "DESFAZER",
              textColor: Colors.yellow,
              onPressed: () => controller.desfazerExclusao(tarefa),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: tarefa.concluida,
              activeColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onChanged: (_) => controller.alternarConclusao(tarefa),
            ),
          ),
          title: Text(
            tarefa.titulo,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              decoration: tarefa.concluida ? TextDecoration.lineThrough : null,
              color: tarefa.concluida ? Colors.grey[400] : const Color(0xFF1E293B),
            ),
          ),
          // --- AQUI ESTÁ A MUDANÇA VISUAL ---
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  tarefa.concluida && tarefa.dataConclusao != null
                      ? "Concluída em: ${dateFormat.format(tarefa.dataConclusao!)}"
                      : "Iniciada em: ${dateFormat.format(tarefa.dataCriacao)}",
                  style: TextStyle(fontSize: 12, color: tarefa.concluida ? const Color(0xFF10B981) : Colors.grey[500]),
                ),
              ],
            ),
          ),
          onTap: () => _mostrarDialogo(context, controller, tarefa),
        ),
      ),
    );
  }

  // Dialogo único para CRIAR ou EDITAR
  void _mostrarDialogo(BuildContext context, TarefaController controller, Tarefa? tarefaExistente) {
    final textoController = TextEditingController(text: tarefaExistente?.titulo ?? "");
    final isEditando = tarefaExistente != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditando ? "Editar Tarefa" : "Nova Tarefa"),
          content: TextField(
            controller: textoController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: "Ex: Treinar Peito...",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (textoController.text.isNotEmpty) {
                  if (isEditando) {
                    controller.atualizarTitulo(tarefaExistente, textoController.text);
                  } else {
                    controller.adicionar(textoController.text);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(isEditando ? "Atualizar" : "Salvar", style: const TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }
}