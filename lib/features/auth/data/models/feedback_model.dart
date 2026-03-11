import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart'; // Ajuste o caminho das suas cores

void mostrarFormularioFeedbackBeta(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final TextEditingController confusoCtrl = TextEditingController();
  final TextEditingController bugCtrl = TextEditingController();
  final TextEditingController gostouCtrl = TextEditingController();
  double notaGeral = 5.0; // Nota inicial
  bool enviando = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Permite que o modal suba quase até o topo
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85, // Ocupa 85% da tela
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, // Foge do teclado
              left: 20, right: 20, top: 20,
            ),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50, height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.bug_report, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text("Feedback de Teste (Beta)", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text("Sua opinião vai ajudar a polir o Okan antes do lançamento oficial!", style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 20),

                Expanded(
                  child: ListView(
                    children: [
                      // --- PERGUNTA 1: NOTA ---
                      const Text("1. Que nota você dá para o app?", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      Slider(
                        value: notaGeral,
                        min: 1, max: 5, divisions: 4,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.white12,
                        label: notaGeral.toInt().toString(),
                        onChanged: (val) => setStateModal(() => notaGeral = val),
                      ),
                      Center(child: Text("${notaGeral.toInt()} de 5 Estrelas", style: const TextStyle(color: Colors.white))),
                      const SizedBox(height: 20),

                      // --- PERGUNTA 2: USABILIDADE ---
                      const Text("2. O que achou mais confuso ou difícil de usar?", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildFeedbackInput(confusoCtrl, "Ex: Não entendi como adicionar a carga..."),
                      const SizedBox(height: 20),

                      // --- PERGUNTA 3: BUGS ---
                      const Text("3. Encontrou algum erro (bug)? Onde?", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildFeedbackInput(bugCtrl, "Ex: O botão X travou a tela..."),
                      const SizedBox(height: 20),

                      // --- PERGUNTA 4: ELOGIOS ---
                      const Text("4. O que você mais gostou?", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _buildFeedbackInput(gostouCtrl, "Ex: Achei as cores incríveis..."),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- BOTÃO DE ENVIAR ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: enviando ? null : () async {
                      setStateModal(() => enviando = true);
                      
                      try {
                        // Salva na coleção separada 'beta_feedback'
                        await FirebaseFirestore.instance.collection('beta_feedback').add({
                          'userId': user.uid,
                          'timestamp': FieldValue.serverTimestamp(),
                          'nota': notaGeral.toInt(),
                          'confuso': confusoCtrl.text,
                          'bugs': bugCtrl.text,
                          'gostou': gostouCtrl.text,
                          'status': 'novo', // Para você marcar depois se já corrigiu
                        });
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback enviado! Muito obrigado! 💙"), backgroundColor: AppColors.primary));
                        }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
                        setStateModal(() => enviando = false);
                      }
                    },
                    child: enviando 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("ENVIAR FEEDBACK", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      );
    }
  );
}

// Widget auxiliar para os campos de texto não ficarem repetitivos
Widget _buildFeedbackInput(TextEditingController ctrl, String hint) {
  return TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white),
    maxLines: 2,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );
}