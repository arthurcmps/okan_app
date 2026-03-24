import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
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

  // Chave Pública do Mercado Pago
  final String _mercadoPagoPublicKey = "TEST-13b66d79-52ea-410d-9efb-57db088806b4";

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

  void _processarAquisicao(String templateId, Map<String, dynamic> treinoData) {
    final double preco = (treinoData['preco'] ?? 0.0).toDouble();

    if (preco <= 0) {
      _registrarCompraNoPerfil(templateId); 
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.background,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: TemplateCheckoutSheet(
            templateId: templateId,
            templateNome: treinoData['nome'] ?? 'Treino Premium',
            preco: preco,
            publicKey: _mercadoPagoPublicKey,
            usuarioAtual: user,
            onSuccess: () {
              _registrarCompraNoPerfil(templateId); 
            },
          ),
        ),
      );
    }
  }

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
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Treino aplicado com sucesso à sua semana! 💪"), backgroundColor: AppColors.primary));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao aplicar: $e")));
      }
    }
  }

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
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: jaAdquirido ? AppColors.secondary : AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context); 
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
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            
            final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
            final List<String> meusTreinosIds = List<String>.from(userData['purchased_templates'] ?? []);

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('workout_templates').where('isPremium', isEqualTo: true).snapshots(),
              builder: (context, templatesSnapshot) {
                if (templatesSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                
                final allTemplates = templatesSnapshot.data?.docs ?? [];
                final lojaTemplates = allTemplates.where((doc) => !meusTreinosIds.contains(doc.id)).toList();
                final meusTemplates = allTemplates.where((doc) => meusTreinosIds.contains(doc.id)).toList();

                return TabBarView(
                  children: [
                    _buildListaTreinos(lojaTemplates, true),
                    _buildListaTreinos(meusTemplates, false),
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
          isLoja ? "Nenhum treino novo disponível no momento." : "Sua biblioteca está vazia.\nAdquira treinos na loja!", 
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 16)
        )
      );
    }

    var treinos = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final tagsDoTreino = data['tags'] as List<dynamic>? ?? [];
      final score = isLoja ? _calcularScoreDeMatch(tagsDoTreino) : 0;
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

// ============================================================================
// COMPONENTE DE CHECKOUT
// ============================================================================
class TemplateCheckoutSheet extends StatefulWidget {
  final String templateId;
  final String templateNome;
  final double preco;
  final String publicKey;
  final User usuarioAtual;
  final VoidCallback onSuccess;

  const TemplateCheckoutSheet({
    super.key, 
    required this.templateId, 
    required this.templateNome, 
    required this.preco, 
    required this.publicKey, 
    required this.usuarioAtual,
    required this.onSuccess,
  });

  @override
  State<TemplateCheckoutSheet> createState() => _TemplateCheckoutSheetState();
}

class _TemplateCheckoutSheetState extends State<TemplateCheckoutSheet> {
  int _metodoSelecionado = 0; 
  bool _isProcessing = false;
  String? _qrCodeBase64;
  String? _pixCopiaCola;

  final _numCartaoCtrl = TextEditingController();
  final _validadeCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  Future<void> _gerarPix() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('criarPagamentoPix');
      final response = await callable.call({'planoNome': widget.templateNome, 'preco': widget.preco});
      
      setState(() {
        _qrCodeBase64 = response.data['qr_code_base64'];
        _pixCopiaCola = response.data['qr_code'];
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _mostrarErro("Erro ao gerar PIX: $e");
    }
  }

  String _traduzirErroMercadoPago(String code, String fallback) {
    switch (code) {
      case '205': return "Digite o número do seu cartão.";
      case '208':
      case '209': return "Mês ou ano de validade inválido.";
      case '212':
      case '213':
      case '214': return "Informe seu CPF corretamente.";
      case '221': return "Digite o nome igual ao do cartão.";
      case '224': return "Digite o CVV (código de segurança).";
      case 'E301': return "Número do cartão inválido.";
      case 'E302': return "CVV inválido. Verifique o código no verso.";
      case '316': return "Nome do titular inválido.";
      case '322':
      case '323':
      case '324': return "CPF inválido. Verifique os números.";
      case '325':
      case '326': return "Data de validade incorreta ou expirada.";
      default: return fallback;
    }
  }

  Future<void> _processarCartao() async {
    if (_numCartaoCtrl.text.isEmpty || _cvvCtrl.text.isEmpty || _cpfCtrl.text.isEmpty || _validadeCtrl.text.isEmpty) {
      _mostrarErro("Preencha todos os campos do cartão.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      String numCartao = _numCartaoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      String dataValidade = _validadeCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      
      if (dataValidade.length < 4) throw Exception("A validade do cartão deve ter o formato MM/AA.");
      
      final mes = dataValidade.substring(0, 2);
      final anoRaw = dataValidade.substring(2);
      final ano = anoRaw.length == 2 ? "20$anoRaw" : anoRaw;

      // Descobre a bandeira automaticamente pelo primeiro dígito para não forçar "master"
      String metodoPagamentoStr = 'master';
      if (numCartao.startsWith('4')) metodoPagamentoStr = 'visa';
      else if (numCartao.startsWith('3')) metodoPagamentoStr = 'amex';
      else if (numCartao.startsWith('6')) metodoPagamentoStr = 'elo';

      await FirebaseAuth.instance.currentUser?.getIdToken(true);

      final url = Uri.parse('https://api.mercadopago.com/v1/card_tokens?public_key=${widget.publicKey}');
      final mpResponse = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "card_number": numCartao,
          "expiration_month": int.parse(mes),
          "expiration_year": int.parse(ano),
          "security_code": _cvvCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
          "cardholder": {
            "name": _nomeCtrl.text,
            "identification": {
              "type": "CPF",
              "number": _cpfCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')
            }
          }
        }),
      );

      final tokenData = jsonDecode(mpResponse.body);
      
      if (tokenData['id'] == null) {
        String msgErro = 'Dados inválidos. Verifique as informações.';
        if (tokenData['cause'] != null && tokenData['cause'].isNotEmpty) {
          String causeCode = tokenData['cause'][0]['code'].toString();
          msgErro = _traduzirErroMercadoPago(causeCode, tokenData['cause'][0]['description']);
        } else if (tokenData['message'] != null) {
          msgErro = tokenData['message'];
        }
        throw Exception(msgErro);
      }

      final String cardToken = tokenData['id'];

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('criarPagamentoCartao');
      final result = await callable.call({
        'planoNome': widget.templateNome,
        'preco': widget.preco,
        'tokenCartao': cardToken,
        'parcelas': 1, 
        'metodoPagamentoId': metodoPagamentoStr, 
        'emailPagador': widget.usuarioAtual.email ?? 'email@teste.com',
        'tipoDoc': 'CPF',
        'numeroDoc': _cpfCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      });

      if (result.data['status'] == 'approved' || result.data['status'] == 'in_process') {
        if (mounted) {
          Navigator.pop(context); 
          widget.onSuccess(); 
        }
      } else {
        throw Exception(result.data['status_detail']);
      }

    } catch (e) {
      _mostrarErro(e.toString());
    } finally {
      if(mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg.replaceAll('Exception:', '').trim()), backgroundColor: AppColors.error));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Comprar Treino", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("${widget.templateNome} - R\$ ${widget.preco.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.primary, fontSize: 16)),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(child: ChoiceChip(
                label: const Text("Pagar com PIX"),
                selected: _metodoSelecionado == 0,
                onSelected: (val) => setState(() { _metodoSelecionado = 0; _qrCodeBase64 = null; }),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _metodoSelecionado == 0 ? Colors.black : Colors.white),
              )),
              const SizedBox(width: 12),
              Expanded(child: ChoiceChip(
                label: const Text("Cartão de Crédito"),
                selected: _metodoSelecionado == 1,
                onSelected: (val) => setState(() { _metodoSelecionado = 1; _qrCodeBase64 = null; }),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _metodoSelecionado == 1 ? Colors.black : Colors.white),
              )),
            ],
          ),
          
          const SizedBox(height: 24),

          Expanded(
            child: _metodoSelecionado == 0 ? _buildPixView() : _buildCartaoView(),
          )
        ],
      ),
    );
  }

  Widget _buildPixView() {
    if (_qrCodeBase64 != null && _pixCopiaCola != null) {
      return Column(
        children: [
          const Text("Escaneie o QR Code abaixo:", style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Image.memory(base64Decode(_qrCodeBase64!), width: 200, height: 200),
          ),
          const SizedBox(height: 24),
          const Text("Ou copie o código PIX:", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(_pixCopiaCola!, style: const TextStyle(color: AppColors.primary, fontSize: 12)),
          ),
          const Spacer(),
          const Text("Aguardando pagamento... O seu treino será liberado automaticamente assim que o banco confirmar.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
    }

    return Center(
      child: _isProcessing 
        ? const CircularProgressIndicator(color: AppColors.primary)
        : ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            icon: const Icon(Icons.qr_code, color: Colors.black),
            label: const Text("GERAR CÓDIGO PIX", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: _gerarPix,
          ),
    );
  }

  Widget _buildCartaoView() {
    return ListView(
      children: [
        _buildTextField(_numCartaoCtrl, "Número do Cartão", Icons.credit_card, TextInputType.number, formatters: [CardInputFormatter()]),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField(_validadeCtrl, "Validade (MM/AA)", Icons.date_range, TextInputType.number, formatters: [DateInputFormatter()])),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_cvvCtrl, "CVV", Icons.security, TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)])),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(_nomeCtrl, "Nome impresso no cartão", Icons.person, TextInputType.name),
        const SizedBox(height: 12),
        _buildTextField(_cpfCtrl, "CPF do Titular", Icons.badge, TextInputType.number, formatters: [CpfInputFormatter()]),
        
        const SizedBox(height: 30),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _isProcessing ? null : _processarCartao,
            child: _isProcessing 
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text("CONFIRMAR PAGAMENTO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, TextInputType type, {List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);
    var formatted = '';
    for (int i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 1 && text.length > 2) formatted += '/';
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class CardInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 16) text = text.substring(0, 16);
    var formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) formatted += ' ';
      formatted += text[i];
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 11) text = text.substring(0, 11);
    var formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i == 3 || i == 6) formatted += '.';
      if (i == 9) formatted += '-';
      formatted += text[i];
    }
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}