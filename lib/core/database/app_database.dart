import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'diario_emocional.db');

    return await openDatabase(
      path,
      version: 2,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notas (
        id INTEGER PRIMARY KEY,
        texto TEXT NOT NULL,
        pasta TEXT NOT NULL DEFAULT 'Geral',
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE pastas (
        nome TEXT PRIMARY KEY
      );
    ''');

    for (final pastaPadrao in ['Geral', 'Desabafos', 'Ideias', 'Metas']) {
      await db.insert('pastas', {'nome': pastaPadrao});
    }

    await db.execute('''
      CREATE TABLE nota_emocoes (
        nota_id INTEGER NOT NULL,
        emocao_id INTEGER NOT NULL,
        PRIMARY KEY (nota_id, emocao_id),
        FOREIGN KEY (nota_id) REFERENCES notas (id) ON DELETE CASCADE
      );
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE notas ADD COLUMN pasta TEXT NOT NULL DEFAULT 'Geral';",
      );
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pastas (
          nome TEXT PRIMARY KEY
        );
      ''');
      for (final pastaPadrao in ['Geral', 'Desabafos', 'Ideias', 'Metas']) {
        await db.insert(
          'pastas',
          {'nome': pastaPadrao},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
