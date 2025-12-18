import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'library_admin_page.dart'; // Certifique-se que este arquivo existe

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Controladores de texto
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _objetivoController = TextEditingController();
  
  // Variável para guardar a data temporariamente enquanto edita
  DateTime? _dataNascimentoTemp;

  // Função auxiliar para calcular idade
  String _calcularIdade(DateTime? nascimento) {
    if (nascimento == null) return "--";
    
    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    
    // Verifica se já fez aniversário este ano
    if (hoje.month < nascimento.month || 
       (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }
    
    return idade.toString();
  }

  // Função para abrir o diálogo de edição
  void _editarPerfil(DateTime? nascimentoAtual, String? pesoAtual, String? objetivoAtual) {
    // Inicializa os dados no diálogo
    _dataNascimentoTemp = nascimentoAtual;
    _pesoController.text = pesoAtual ?? "";
    _objetivoController.text = objetivoAtual ?? "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Editar Meus Dados"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // CAMPO DE DATA DE NASCIMENTO
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake, color: Colors.grey),
                      title: Text(
                        _dataNascimentoTemp == null 
                          ? "Toque para escolher a data" 
                          : "Nascido em: ${_dataNascimentoTemp!.day}/${_dataNascimentoTemp!.month}/${_dataNascimentoTemp!.year}",
                        style: TextStyle(
                          color: _dataNascimentoTemp == null ? Colors.grey : Colors.black
                        ),
                      ),
                      onTap: () async {
                        final dataEscolhida = await showDatePicker(
                          context: context,
                          initialDate: _dataNascimentoTemp ?? DateTime(2000),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                        );
                        
                        if (dataEscolhida != null) {
                          setStateDialog(() {
                            _dataNascimentoTemp = dataEscolhida;
                          });
                        }
                      },
                    ),
                    const Divider(),
                    TextField(
                      controller: _pesoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Peso (kg)", 
                        icon: Icon(Icons.monitor_weight)
                      ),
                    ),
                    TextField(
                      controller: _objetivoController,
                      decoration: const InputDecoration(
                        labelText: "Objetivo", 
                        icon: Icon(Icons.flag)
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    // Salva no Firestore
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'birthDate': _dataNascimentoTemp != null 
                          ? Timestamp.fromDate(_dataNascimentoTemp!) 
                          : null,
                      'weight': double.tryParse(_pesoController.text.replaceAll(',', '.')) ?? 0.0,
                      'objectives': _objetivoController.text,
                      'lastUpdate': FieldValue.serverTimestamp(),
                      'name': user.displayName ?? "Aluno",
                      'email': user.email,
                    }, SetOptions(merge: true));

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Salvar"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meu Perfil"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshotUser) {
          
          String idadeCalculada = "--";
          DateTime? dataNascimento;
          String peso = "--";
          String objetivo = "Definir objetivo";
          
          if (snapshotUser.hasData && snapshotUser.data!.exists) {
            final data = snapshotUser.data!.data() as Map<String, dynamic>;
            
            if (data['birthDate'] != null) {
              final Timestamp t = data['birthDate'];
              dataNascimento = t.toDate();
              idadeCalculada = _calcularIdade(dataNascimento);
            }

            peso = data['weight']?.toString() ?? "--";
            objetivo = data['objectives']?.toString() ?? "Definir objetivo";
          }

          return Column(
            children: [
              // --- PARTE 1: HEADER AZUL ---
              Container(
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue,
                          child: Text(
                            user?.displayName?.substring(0, 1).toUpperCase() ?? "A",
                            style: const TextStyle(fontSize: 30, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? "Atleta",
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              InkWell(
                                onTap: () => _editarPerfil(dataNascimento, peso, objetivo),
                                child: const Row(
                                  children: [
                                    Icon(Icons.edit, size: 14, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text("Editar Perfil", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem("Idade", "$idadeCalculada anos"),
                        _buildStatItem("Peso", "$peso kg"),
                        _buildStatItem("Objetivo", objetivo),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- PARTE 2: BOTÃO NOVO DE ADMIN (Inserido aqui!) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListTile(
                  tileColor: Colors.purple.shade50,
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                  title: const Text("Gerenciar Biblioteca (Admin)"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LibraryAdminPage()),
                    );
                  },
                ),
              ),
              // -----------------------------------------------------

              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Histórico de Treinos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              // --- PARTE 3: LISTA DE HISTÓRICO ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('historico')
                      .where('usuarioId', isEqualTo: user?.uid)
                      .orderBy('data', descending: true)
                      .snapshots(),
                  builder: (context, snapshotHist) {
                    if (!snapshotHist.hasData || snapshotHist.data!.docs.isEmpty) {
                      return const Center(child: Text("Sem treinos registrados."));
                    }
                    final historico = snapshotHist.data!.docs;
                    return ListView.builder(
                      itemCount: historico.length,
                      itemBuilder: (context, index) {
                         final dados = historico[index].data() as Map<String, dynamic>;
                         final nome = dados['treinoNome'] ?? 'Treino';
                         final Timestamp? t = dados['data'];
                         final d = t?.toDate() ?? DateTime.now();
                         return ListTile(
                           leading: const Icon(Icons.check_circle, color: Colors.green),
                           title: Text(nome),
                           subtitle: Text("${d.day}/${d.month} - ${d.hour}:${d.minute}"),
                         );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}