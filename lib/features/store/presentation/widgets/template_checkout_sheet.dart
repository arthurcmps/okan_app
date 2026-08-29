import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/store_models.dart';
import '../../domain/repositories/store_repository.dart';

class TemplateCheckoutSheet extends StatefulWidget {
  const TemplateCheckoutSheet({
    super.key,
    required this.template,
    required this.payerEmail,
    required this.repository,
    required this.onSuccess,
  });

  final StoreTemplate template;
  final String payerEmail;
  final StoreRepository repository;
  final VoidCallback onSuccess;

  @override
  State<TemplateCheckoutSheet> createState() => _TemplateCheckoutSheetState();
}

class _TemplateCheckoutSheetState extends State<TemplateCheckoutSheet> {
  int _method = 0;
  bool _processing = false;
  String? _qrCodeBase64;
  String? _pixCopyPaste;

  final _cardCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  @override
  void dispose() {
    _cardCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  Future<void> _generatePix() async {
    setState(() => _processing = true);
    try {
      final pix = await widget.repository.createPixPayment(widget.template.id);
      if (!mounted) return;
      setState(() {
        _qrCodeBase64 = pix.qrCodeBase64;
        _pixCopyPaste = pix.copyPasteCode;
      });
    } catch (error) {
      _showError('Erro ao gerar PIX: $error');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _payCard() async {
    if (_cardCtrl.text.isEmpty ||
        _cvvCtrl.text.isEmpty ||
        _cpfCtrl.text.isEmpty ||
        _expiryCtrl.text.isEmpty) {
      _showError('Preencha todos os campos do cartão.');
      return;
    }

    final cardNumber = _digits(_cardCtrl.text);
    final expiry = _digits(_expiryCtrl.text);
    if (expiry.length < 4) {
      _showError('A validade do cartão deve ter o formato MM/AA.');
      return;
    }

    setState(() => _processing = true);
    try {
      final yearRaw = expiry.substring(2);
      final result = await widget.repository.createCardPayment(
        CardPaymentRequest(
          templateId: widget.template.id,
          cardNumber: cardNumber,
          expirationMonth: int.parse(expiry.substring(0, 2)),
          expirationYear: int.parse(
            yearRaw.length == 2 ? '20$yearRaw' : yearRaw,
          ),
          securityCode: _digits(_cvvCtrl.text),
          cardholderName: _nameCtrl.text.trim(),
          documentNumber: _digits(_cpfCtrl.text),
          payerEmail: widget.payerEmail,
        ),
      );

      if (result.approved) {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onSuccess();
        return;
      }
      if (result.status == 'in_process') {
        throw StateError(
          'Pagamento em análise. O treino será liberado somente após a aprovação.',
        );
      }
      throw StateError(result.statusDetail ?? 'Pagamento não aprovado.');
    } catch (error) {
      _showError(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Comprar Treino',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.template.name} - R\$ ${widget.template.price.toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.primary, fontSize: 16),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Pagar com PIX'),
                  selected: _method == 0,
                  onSelected: (_) => setState(() {
                    _method = 0;
                    _qrCodeBase64 = null;
                  }),
                  selectedColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Cartão de Crédito'),
                  selected: _method == 1,
                  onSelected: (_) => setState(() {
                    _method = 1;
                    _qrCodeBase64 = null;
                  }),
                  selectedColor: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _method == 0 ? _pixView() : _cardView()),
        ],
      ),
    );
  }

  Widget _pixView() {
    if (_qrCodeBase64 != null && _pixCopyPaste != null) {
      return Column(
        children: [
          const Text('Escaneie o QR Code abaixo:'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Image.memory(
              base64Decode(_qrCodeBase64!),
              width: 200,
              height: 200,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Ou copie o código PIX:'),
          const SizedBox(height: 8),
          SelectableText(
            _pixCopyPaste!,
            style: const TextStyle(color: AppColors.primary, fontSize: 12),
          ),
          const Spacer(),
          const Text(
            'Aguardando pagamento. O treino será liberado automaticamente após a confirmação.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    return Center(
      child: _processing
          ? const CircularProgressIndicator(color: AppColors.primary)
          : ElevatedButton.icon(
              onPressed: _generatePix,
              icon: const Icon(Icons.qr_code),
              label: const Text('GERAR CÓDIGO PIX'),
            ),
    );
  }

  Widget _cardView() {
    return ListView(
      children: [
        _field(
          _cardCtrl,
          'Número do Cartão',
          TextInputType.number,
          formatters: [CardInputFormatter()],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _field(
                _expiryCtrl,
                'Validade (MM/AA)',
                TextInputType.number,
                formatters: [DateInputFormatter()],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                _cvvCtrl,
                'CVV',
                TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _field(_nameCtrl, 'Nome impresso no cartão', TextInputType.name),
        const SizedBox(height: 12),
        _field(
          _cpfCtrl,
          'CPF do Titular',
          TextInputType.number,
          formatters: [CpfInputFormatter()],
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _processing ? null : _payCard,
          child: _processing
              ? const CircularProgressIndicator()
              : const Text('CONFIRMAR PAGAMENTO'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    TextInputType type, {
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception:', '').trim()),
        backgroundColor: AppColors.error,
      ),
    );
  }

  static String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 1 && text.length > 2) buffer.write('/');
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CardInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 16) text = text.substring(0, 16);
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 11) digits = digits.substring(0, 11);
    var formatted = digits;
    if (digits.length > 3) {
      formatted = '${digits.substring(0, 3)}.${digits.substring(3)}';
    }
    if (digits.length > 6) {
      formatted = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6)}';
    }
    if (digits.length > 9) {
      formatted = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
