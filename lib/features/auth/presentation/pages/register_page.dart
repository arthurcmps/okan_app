import 'package:flutter/material.dart';
import '../../../../core/services/auth_service.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthDateController = TextEditingController();
  
  String _selectedRole = 'aluno';
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  void _formatDate(String text) {
    text = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);
    
    String formatted = "";
    if (text.isNotEmpty) {
      if (text.length <= 2) {
        formatted = text;
      } else if (text.length <= 4) {
        formatted = "${text.substring(0, 2)}/${text.substring(2)}";
      } else {
        formatted = "${text.substring(0, 2)}/${text.substring(2, 4)}/${text.substring(4)}";
      }
    }
    
    _birthDateController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      DateTime? birthDate;
      try {
        final parts = _birthDateController.text.split('/');
        if (parts.length == 3) {
          birthDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (e) {
        // Data inválida ignorada
      }

      // CHAMADA CORRIGIDA
      final erro = await _authService.cadastrarUsuario(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nome: _nameController.text.trim(),      // <--- Corrigido (era name)
        tipo: _selectedRole,                    // <--- Corrigido (era role)
        dataNascimento: birthDate,              // <--- Corrigido (era birthDate)
      );

      setState(() => _isLoading = false);

      if (erro == null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(erro ?? "Erro desconhecido"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Criar Conta")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Vamos começar!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text("Preencha seus dados abaixo", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 32),

              const Text("Eu sou:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildRoleCard(label: "Aluno", value: "aluno", icon: Icons.fitness_center, color: Colors.blue)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRoleCard(label: "Personal", value: "personal", icon: Icons.assignment_ind, color: Colors.purple)),
                ],
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nome Completo", prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? "Campo obrigatório" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "E-mail", prefixIcon: Icon(Icons.email)),
                validator: (v) => v!.contains('@') ? null : "E-mail inválido",
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Senha", prefixIcon: Icon(Icons.lock)),
                validator: (v) => v!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _birthDateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Data de Nascimento (dd/mm/aaaa)", prefixIcon: Icon(Icons.calendar_today)),
                onChanged: _formatDate,
                validator: (v) => v!.length < 10 ? "Data inválida" : null,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _selectedRole == 'personal' ? Colors.purple : Colors.blue,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("CRIAR CONTA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({required String label, required String value, required IconData icon, required Color color}) {
    final isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? color : Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? color : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? color : Colors.grey, fontWeight: FontWeight.bold)),
            if (isSelected) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.check_circle, size: 16, color: Colors.green))
          ],
        ),
      ),
    );
  }
}