class DateUtil {
  static String calcularIdade(dynamic dataNascimento) {
    if (dataNascimento == null) return "--";

    DateTime nascimento;
    
    // Tenta converter se vier como Timestamp (Firestore) ou String
    if (dataNascimento is DateTime) {
      nascimento = dataNascimento;
    } else if (dataNascimento is String) {
      try {
        // Tenta formatos comuns dd/MM/yyyy ou yyyy-MM-dd
        if (dataNascimento.contains('/')) {
          final parts = dataNascimento.split('/');
          nascimento = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        } else {
          nascimento = DateTime.parse(dataNascimento);
        }
      } catch (e) {
        return "--";
      }
    } else {
      // Se for Timestamp do Firestore
      try {
        nascimento = dataNascimento.toDate();
      } catch (e) {
        return "--";
      }
    }

    final hoje = DateTime.now();
    int idade = hoje.year - nascimento.year;
    
    // Ajuste se ainda não fez aniversário este ano
    if (hoje.month < nascimento.month || 
       (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      idade--;
    }

    return "$idade anos";
  }
}