import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';

class PersonalDataPage extends StatefulWidget {
  final String uid;
  const PersonalDataPage({super.key, required this.uid});

  @override
  State<PersonalDataPage> createState() => _PersonalDataPageState();
}

class _PersonalDataPageState extends State<PersonalDataPage> {
  String? _selectedGender;
  DateTime? _birthDate;
  bool _isLoading = false;

  // Lista de opções de gênero atualizada
  final List<String> _genderOptions = [
    "Mulher Cis",
    "Mulher Trans",
    "Homem Cis",
    "Homem Trans",
    "Não-Binário",
    "Outro"
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _selectedGender = data['gender'];
        
        // Carrega data de nascimento
        if (data['birthDate'] != null) {
          _birthDate = (data['birthDate'] as Timestamp).toDate();
        }
      });
    }
  }

  // --- SALVAR DADOS GERAIS ---
  Future<void> _saveGeneralData() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'gender': _selectedGender,
        'birthDate': _birthDate,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Dados atualizados com sucesso!"), backgroundColor: AppColors.success)
        );
        Navigator.pop(context); // Volta para o perfil
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ALTERAR SENHA ---
  void _showChangePasswordDialog() {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white10)),
        title: const Text("Alterar Senha", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Digite sua nova senha abaixo:", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            TextField(
              controller: passController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Nova Senha", 
                prefixIcon: Icon(Icons.lock_outline, color: AppColors.secondary)
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Confirmar Senha", 
                prefixIcon: Icon(Icons.lock, color: AppColors.secondary)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
            ),
            onPressed: () async {
              if (passController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("As senhas não coincidem."), backgroundColor: AppColors.error));
                return;
              }
              if (passController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A senha deve ter no mínimo 6 caracteres."), backgroundColor: AppColors.error));
                return;
              }

              try {
                await FirebaseAuth.instance.currentUser?.updatePassword(passController.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha alterada!"), backgroundColor: AppColors.success));
                }
              } on FirebaseAuthException catch (e) {
                if (e.code == 'requires-recent-login') {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por segurança, faça logout e login novamente para trocar a senha."), backgroundColor: AppColors.warning));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: ${e.message}"), backgroundColor: AppColors.error));
                }
              }
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  // --- SELETOR DE DATA ---
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary, // Neon no calendário
              onPrimary: Colors.black,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Informações Pessoais", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            
            // --- DATA DE NASCIMENTO ---
            _buildSectionTitle("Data de Nascimento"),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake, color: AppColors.secondary),
                    const SizedBox(width: 12),
                    Text(
                      _birthDate == null 
                        ? "Toque para selecionar" 
                        : DateFormat('dd/MM/yyyy').format(_birthDate!),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // --- GÊNERO / IDENTIDADE ---
            _buildSectionTitle("Identidade de Gênero"),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline, color: AppColors.secondary),
                filled: true,
                fillColor: AppColors.surface,
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primary)),
              ),
              hint: const Text("Selecione (Opcional)", style: TextStyle(color: Colors.white54)),
              items: _genderOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
            ),

            const SizedBox(height: 48),

            // --- BOTÃO SALVAR ---
            ElevatedButton(
              onPressed: _isLoading ? null : _saveGeneralData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, // Botão Neon
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text("SALVAR ALTERAÇÕES", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),

            const SizedBox(height: 30),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),

            // --- BOTÃO TROCAR SENHA ---
            TextButton.icon(
              icon: const Icon(Icons.lock_reset, color: AppColors.textSub),
              label: const Text("Alterar minha senha", style: TextStyle(color: AppColors.textSub)),
              onPressed: _showChangePasswordDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(color: AppColors.secondary, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }
}