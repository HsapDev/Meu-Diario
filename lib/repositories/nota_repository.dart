import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/database/app_database.dart';
import '../models/emocao.dart';
import '../models/nota.dart';

class NotaRepository {
  final AppDatabase _appDatabase;

  NotaRepository({AppDatabase? appDatabase})
      : _appDatabase = appDatabase ?? AppDatabase.instance;

  Future<Database> get _db async => await _appDatabase.database;

  Future<int> _obterMenorIdLivre(Transaction txn) async {
    final rows = await txn.query('notas', columns: ['id'], orderBy: 'id ASC');
    final idsOcupados = rows.map((r) => r['id'] as int).toSet();
    int candidato = 1;
    while (idsOcupados.contains(candidato)) {
      candidato++;
    }
    return candidato;
  }

  Future<List<String>> listarPastas() async {
    final db = await _db;
    final rows = await db.query('pastas', orderBy: 'nome ASC');
    final lista = rows.map((r) => r['nome'] as String).toList();
    if (!lista.contains('Geral')) {
      lista.insert(0, 'Geral');
    } else {
      lista.remove('Geral');
      lista.insert(0, 'Geral');
    }
    return lista;
  }

  Future<void> criarPasta(String nome) async {
    final limpo = nome.trim();
    if (limpo.isEmpty) return;
    final db = await _db;
    await db.insert(
      'pastas',
      {'nome': limpo},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> salvar(Nota nota) async {
    final db = await _db;

    final int idFinal = await db.transaction<int>((txn) async {
      int notaId;

      await txn.insert(
        'pastas',
        {'nome': nota.pasta},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      if (nota.id == null) {
        notaId = await _obterMenorIdLivre(txn);
        await txn.insert('notas', {
          'id': notaId,
          'texto': nota.texto,
          'pasta': nota.pasta,
          'created_at': nota.createdAt.toIso8601String(),
        });
      } else {
        notaId = nota.id!;
        await txn.update(
          'notas',
          {
            'texto': nota.texto,
            'pasta': nota.pasta,
            'created_at': nota.createdAt.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [notaId],
        );

        await txn.delete(
          'nota_emocoes',
          where: 'nota_id = ?',
          whereArgs: [notaId],
        );
      }

      for (final emocao in nota.emocoes) {
        await txn.insert('nota_emocoes', {
          'nota_id': notaId,
          'emocao_id': emocao.index,
        });
      }

      return notaId;
    });

    return idFinal;
  }

  Future<String> obterDiretorioMarkdownBase() async {
    final dbPath = await getDatabasesPath();
    final parentDir = Directory(dbPath).parent.path;
    final mdDir = Directory(p.join(parentDir, 'markdown_notas'));
    if (!await mdDir.exists()) {
      await mdDir.create(recursive: true);
    }
    return mdDir.path;
  }

  Future<String> exportarNotaMarkdown(Nota nota, String pastaDestino) async {
    await criarPasta(pastaDestino);
    final baseDir = await obterDiretorioMarkdownBase();
    final nomePastaSegura =
        pastaDestino.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    final pastaDir = Directory(p.join(baseDir, nomePastaSegura));
    if (!await pastaDir.exists()) {
      await pastaDir.create(recursive: true);
    }
    final notaExportada = Nota(
      id: nota.id,
      texto: nota.texto,
      pasta: pastaDestino,
      createdAt: nota.createdAt,
      emocoes: nota.emocoes,
    );
    final arquivo = File(p.join(pastaDir.path, 'nota_${nota.id}.md'));
    await arquivo.writeAsString(notaExportada.toMarkdown());
    return arquivo.path;
  }

  Future<List<Nota>> listarTodas({String? pasta}) async {
    final db = await _db;

    final List<Map<String, dynamic>> notasMap = await db.query(
      'notas',
      where: (pasta != null && pasta != 'Todas') ? 'pasta = ?' : null,
      whereArgs: (pasta != null && pasta != 'Todas') ? [pasta] : null,
      orderBy: 'id ASC',
    );

    if (notasMap.isEmpty) return [];

    final List<Map<String, dynamic>> vinculosMap = await db.query('nota_emocoes');

    final Map<int, Set<Emocao>> emocoesPorNota = {};
    for (final row in vinculosMap) {
      final nId = row['nota_id'] as int;
      final eId = row['emocao_id'] as int;

      if (eId >= 0 && eId < Emocao.values.length) {
        emocoesPorNota.putIfAbsent(nId, () => <Emocao>{}).add(Emocao.values[eId]);
      }
    }

    return notasMap.map((map) {
      final id = map['id'] as int;
      return Nota(
        id: id,
        texto: map['texto'] as String,
        pasta: (map['pasta'] as String?) ?? 'Geral',
        createdAt: DateTime.parse(map['created_at'] as String),
        emocoes: emocoesPorNota[id] ?? {},
      );
    }).toList();
  }

  Future<void> excluir(int id) async {
    final db = await _db;
    await db.delete(
      'notas',
      where: 'id = ?',
      whereArgs: [id],
    );
    try {
      await db.execute(
        "DELETE FROM sqlite_sequence WHERE name = 'notas';",
      );
    } catch (_) {
      // Tabela pode não usar sqlite_sequence; seguro ignorar.
    }
  }

  Future<Map<Emocao, int>> buscarResumoSemanal() async {
    final db = await _db;
    final seteDiasAtras =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    final List<Map<String, dynamic>> resultado = await db.rawQuery('''
      SELECT ne.emocao_id, COUNT(ne.emocao_id) as total
      FROM nota_emocoes ne
      INNER JOIN notas n ON n.id = ne.nota_id
      WHERE n.created_at >= ?
      GROUP BY ne.emocao_id
      ORDER BY total DESC;
    ''', [seteDiasAtras]);

    final Map<Emocao, int> resumo = {};
    for (final row in resultado) {
      final eId = row['emocao_id'] as int;
      final total = row['total'] as int;
      if (eId >= 0 && eId < Emocao.values.length) {
        resumo[Emocao.values[eId]] = total;
      }
    }
    return resumo;
  }

  Future<DadosOfensiva> calcularOfensiva() async {
    final db = await _db;
    final rows = await db.query('notas', columns: ['created_at']);

    final Set<DateTime> diasComNota = {};
    for (final row in rows) {
      final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (dt != null) {
        diasComNota.add(DateTime(dt.year, dt.month, dt.day));
      }
    }

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final ontem = hoje.subtract(const Duration(days: 1));

    final escreveuHoje = diasComNota.contains(hoje);

    // Calcula a ofensiva atual
    int ofensivaAtual = 0;
    DateTime cursor = escreveuHoje ? hoje : ontem;
    while (diasComNota.contains(cursor)) {
      ofensivaAtual++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Calcula o recorde (melhor ofensiva)
    int melhorOfensiva = 0;
    if (diasComNota.isNotEmpty) {
      final diasOrdenados = diasComNota.toList()..sort();
      int sequencia = 1;
      melhorOfensiva = 1;
      for (int i = 1; i < diasOrdenados.length; i++) {
        final diff = diasOrdenados[i].difference(diasOrdenados[i - 1]).inDays;
        if (diff == 1) {
          sequencia++;
          if (sequencia > melhorOfensiva) {
            melhorOfensiva = sequencia;
          }
        } else if (diff > 1) {
          sequencia = 1;
        }
      }
    }

    // Últimos 7 dias (de 6 dias atrás até hoje)
    final List<DiaOfensiva> ultimos7Dias = [];
    const nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    for (int i = 6; i >= 0; i--) {
      final dia = hoje.subtract(Duration(days: i));
      ultimos7Dias.add(
        DiaOfensiva(
          rotulo: nomesDias[dia.weekday - 1],
          concluido: diasComNota.contains(dia),
          ehHoje: i == 0,
        ),
      );
    }

    return DadosOfensiva(
      ofensivaAtual: ofensivaAtual,
      melhorOfensiva: melhorOfensiva,
      totalDiasRegistrados: diasComNota.length,
      escreveuHoje: escreveuHoje,
      ultimos7Dias: ultimos7Dias,
    );
  }
}

class DiaOfensiva {
  final String rotulo;
  final bool concluido;
  final bool ehHoje;

  const DiaOfensiva({
    required this.rotulo,
    required this.concluido,
    required this.ehHoje,
  });
}

class DadosOfensiva {
  final int ofensivaAtual;
  final int melhorOfensiva;
  final int totalDiasRegistrados;
  final bool escreveuHoje;
  final List<DiaOfensiva> ultimos7Dias;

  const DadosOfensiva({
    required this.ofensivaAtual,
    required this.melhorOfensiva,
    required this.totalDiasRegistrados,
    required this.escreveuHoje,
    required this.ultimos7Dias,
  });
}
