import 'emocao.dart';

class Nota {
  final int? id;
  final String texto;
  final String pasta;
  final DateTime createdAt;
  final Set<Emocao> emocoes;

  Nota({
    this.id,
    this.texto = '',
    this.pasta = 'Geral',
    DateTime? createdAt,
    Set<Emocao>? emocoes,
  }) : createdAt = createdAt ?? DateTime.now(),
       emocoes = emocoes ?? {};

  bool get isValida {
    final temTexto = texto.trim().isNotEmpty;
    final temEmocao = emocoes.isNotEmpty;
    return temTexto || temEmocao;
  }

  String toMarkdown() {
    final dia = createdAt.day.toString().padLeft(2, '0');
    final mes = createdAt.month.toString().padLeft(2, '0');
    final ano = createdAt.year;
    final hora = createdAt.hour.toString().padLeft(2, '0');
    final min = createdAt.minute.toString().padLeft(2, '0');
    final emocoesStr = emocoes.isEmpty
        ? 'Nenhuma'
        : emocoes.map((e) => '${e.emoji} ${e.rotulo}').join(', ');

    return '''# Nota #${id ?? 'Nova'} — $pasta
- **Data:** $dia/$mes/$ano às $hora:$min
- **Emoções:** $emocoesStr

---

$texto
''';
  }
}
