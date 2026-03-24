import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';

class ProfessorSubscriptionPage extends StatefulWidget {
  const ProfessorSubscriptionPage({super.key});

  @override
  State<ProfessorSubscriptionPage> createState() => _ProfessorSubscriptionPageState();
}

class _ProfessorSubscriptionPageState extends State<ProfessorSubscriptionPage> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  final String _mercadoPagoPublicKey = "TEST-13b66d79-52ea-410d-9efb-57db088806b4";

  Future<void> _abrirCheckout(String planoNome, double preco) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CheckoutSheet(
          planoNome: planoNome,
          preco: preco,
          publicKey: _mercadoPagoPublicKey,
          usuarioAtual: user!,
        ),
      ),
    );
  }

  Future<void> _cancelarAssinatura() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text("Cancelar Assinatura?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Tem certeza que deseja voltar ao Plano Base?\n\nVocê perderá acesso às ferramentas premium. Os seus alunos atuais serão mantidos, mas não poderá adicionar novos até estar dentro do limite do plano gratuito (3 alunos).",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Voltar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx); 
              setState(() => _isLoading = true);

              try {
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                  'isPremium': false,
                  'subscriptionPlan': 'Plano Base',
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Assinatura cancelada com sucesso."), backgroundColor: Colors.white24)
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao cancelar: $e"), backgroundColor: AppColors.error));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text("Sim, Cancelar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text("Planos Okan Personal", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final isPremium = userData['isPremium'] == true;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.workspace_premium, size: 80, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text("Evolua o seu negócio", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Escolha o plano ideal para gerir os seus alunos e vender os seus treinos na plataforma.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 40),

                _buildCardPlano(
                  titulo: "Plano Base",
                  preco: "Grátis",
                  descricao: "Para quem está a começar.",
                  isAtivo: !isPremium,
                  corDestaque: Colors.white54,
                  beneficios: ["Até 3 alunos ativos", "Criar e aplicar treinos", "Acesso à biblioteca padrão"],
                  botaoTexto: !isPremium ? "SEU PLANO ATUAL" : "REBAIXAR PLANO",
                  onPressed: !isPremium ? null : _cancelarAssinatura, 
                ),

                const SizedBox(height: 24),

                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildCardPlano(
                      titulo: "Mestre Sankofa",
                      preco: "R\$ 49,90",
                      sufixo: "/mês",
                      descricao: "A ferramenta completa para o Personal.",
                      isAtivo: isPremium,
                      corDestaque: AppColors.primary,
                      beneficios: ["Alunos ILIMITADOS", "Vender templates na Loja", "Gráficos de Evolução", "Duelos na Arena"],
                      botaoTexto: isPremium ? "PLANO ATIVO" : "ASSINAR AGORA",
                      onPressed: isPremium ? null : () => _abrirCheckout("Mestre Sankofa", 49.90),
                    ),
                    if (!isPremium)
                      Positioned(
                        top: -15, right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(20)),
                          child: const Text("MAIS POPULAR", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardPlano({required String titulo, required String preco, String sufixo = "", required String descricao, required bool isAtivo, required Color corDestaque, required List<String> beneficios, required String botaoTexto, required VoidCallback? onPressed}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isAtivo ? corDestaque : Colors.white10, width: isAtivo ? 2 : 1),
        boxShadow: isAtivo ? [BoxShadow(color: corDestaque.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: corDestaque, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(preco, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            Padding(padding: const EdgeInsets.only(bottom: 6.0), child: Text(sufixo, style: const TextStyle(color: Colors.white54, fontSize: 16))),
          ]),
          const SizedBox(height: 8),
          Text(descricao, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(color: Colors.white10)),
          ...beneficios.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(children: [Icon(Icons.check_circle, color: corDestaque, size: 20), const SizedBox(width: 12), Expanded(child: Text(b, style: const TextStyle(color: Colors.white)))]),
          )),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isAtivo ? corDestaque.withOpacity(0.1) : corDestaque, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: onPressed,
              child: _isLoading && !isAtivo 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text(botaoTexto, style: TextStyle(color: isAtivo ? corDestaque : Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENTE DE CHECKOUT 
// ============================================================================
class CheckoutSheet extends StatefulWidget {
  final String planoNome;
  final double preco;
  final String publicKey;
  final User usuarioAtual;

  const CheckoutSheet({super.key, required this.planoNome, required this.preco, required this.publicKey, required this.usuarioAtual});

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
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
      final response = await callable.call({'planoNome': widget.planoNome, 'preco': widget.preco});
      
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

      // Bandeira dinâmica
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
        'planoNome': widget.planoNome,
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pagamento aprovado! O seu plano foi ativado."), backgroundColor: AppColors.success));
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
          const Text("Finalizar Assinatura", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("${widget.planoNome} - R\$ ${widget.preco.toStringAsFixed(2)}", style: const TextStyle(color: AppColors.primary, fontSize: 16)),
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
          const Text("Aguardando pagamento... O seu plano será ativado automaticamente assim que o banco confirmar.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
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