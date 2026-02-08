import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/tarefa_controller.dart';
import '../../data/models/tarefa_controller.dart';

class TarefasPage extends StatelessWidget {
  const TarefasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<TarefaController>(context);
    
    // Separando as listas
    final pendentes = controller.tarefas.where((t) => !t.concluida).toList();
    final concluidas = controller.tarefas.where((t) => t.concluida).toList();
    
    // Cálculo de progresso
    final total = controller.tarefas.length;
    final feitos = concluidas.length;
    final progresso = total == 0 ? 0.0 : feitos / total;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // AppColors.background
      appBar: AppBar(
        title: const Text("Minhas Tarefas", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF1E293B), // Cor do texto
      ),
      body: Column(
        children: [
          // --- BARRA DE PROGRESSO ---
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
                  color: const Color(0xFF2563EB), // AppColors.primary
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(height: 8),
                Text(
                  "$feitos de $total tarefas concluídas",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                )
              ],
            ),
          ),

          // --- LISTA DE TAREFAS ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                if (pendentes.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text("PENDENTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  ),
                  ...pendentes.map((t) => _buildTaskCard(context, t, controller)),
                ],

                if (concluidas.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text("CONCLUÍDAS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                  ),
                  ...concluidas.map((t) => _buildTaskCard(context, t, controller)),
                ],
                
                if (controller.tarefas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 50),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("Nenhuma tarefa ainda!", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                 const SizedBox(height: 80), // Espaço para o FAB
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Nova Tarefa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _mostrarDialogoAdicionar(context, controller),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Tarefa tarefa, TarefaController controller) {
    return Container(
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
            activeColor: const Color(0xFF10B981), // Verde Sucesso
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
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red[300]),
          onPressed: () => controller.remover(tarefa.id),
        ),
      ),
    );
  }

  void _mostrarDialogoAdicionar(BuildContext context, TarefaController controller) {
    final textoController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Nova Tarefa"),
          content: TextField(
            controller: textoController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: "Ex: Tomar creatina...",
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
                  controller.adicionar(textoController.text);
                  Navigator.pop(context);
                }
              },
              child: const Text("Salvar", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }
}