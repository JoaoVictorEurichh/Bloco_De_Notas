import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/utils/text_normalizer.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Fonte de dados local (SQLite).
///
/// Padrão **Singleton** (`DatabaseHelper.instance`): o app inteiro compartilha
/// uma única conexão com o banco. O construtor também aceita uma
/// [DatabaseFactory] e um caminho para que os testes usem um banco em memória
/// (`sqflite_common_ffi`).
class DatabaseHelper {
  static const _dbVersion = 2;
  static const notesTable = 'notes';
  static const categoriesTable = 'categories';

  static final DatabaseHelper instance = DatabaseHelper();

  final DatabaseFactory? _factory;
  final String _fileName;
  Database? _database;

  DatabaseHelper({DatabaseFactory? factory, String fileName = 'notes.db'})
      : _factory = factory,
        _fileName = fileName;

  Future<Database> get database async {
    return _database ??= await _initDB();
  }

  Future<Database> _initDB() async {
    final factory = _factory ?? databaseFactory;
    final path = _fileName == inMemoryDatabasePath
        ? inMemoryDatabasePath
        : join(await factory.getDatabasesPath(), _fileName);

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $notesTable(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status TEXT NOT NULL,
        search_index TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_notes_uid ON $notesTable(uid, sync_status)',
    );
    await db.execute('''
      CREATE TABLE $categoriesTable(
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        name TEXT NOT NULL,
        color_index INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
  }

  /// A versão 1 do projeto base usava `id INTEGER AUTOINCREMENT`, que não
  /// serve para sincronizar entre aparelhos (o mesmo número seria gerado em
  /// instalações diferentes). Além disso o `CREATE TABLE` original tinha uma
  /// vírgula sobrando e não chegava a criar a tabela. Por isso a migração
  /// recria o esquema com ids UUID.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS $notesTable');
      await db.execute('DROP TABLE IF EXISTS $categoriesTable');
      await _createSchema(db);
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  // ===========================================================================
  // Notas
  // ===========================================================================

  /// Insere ou substitui (upsert) uma nota.
  Future<void> upsertNote(Note note) async {
    final db = await database;
    await db.insert(
      notesTable,
      note.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> upsertNotes(Iterable<Note> notes) async {
    final db = await database;
    final batch = db.batch();
    for (final note in notes) {
      batch.insert(notesTable, note.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Note?> getNote(String id) async {
    final db = await database;
    final rows = await db.query(notesTable, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Note.fromDbMap(rows.first);
  }

  /// Consulta as notas visíveis do usuário aplicando pesquisa (título ou
  /// conteúdo), categoria, lixeira e ordenação.
  ///
  /// Registros marcados como [SyncStatus.pendingDelete] nunca aparecem.
  Future<List<Note>> queryNotes(String uid, NoteFilter filter) async {
    final db = await database;
    final where = <String>['uid = ?', 'sync_status != ?'];
    final args = <Object?>[uid, SyncStatus.pendingDelete.name];

    where.add(filter.inTrash ? 'deleted_at IS NOT NULL' : 'deleted_at IS NULL');

    if (filter.categoryId != null) {
      where.add('category_id = ?');
      args.add(filter.categoryId);
    }

    final term = normalizeForSearch(filter.searchTerm.trim());
    if (term.isNotEmpty) {
      // Escapa os curingas do LIKE para que "%" e "_" sejam literais.
      final escaped = term
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      where.add(r"search_index LIKE ? ESCAPE '\'");
      args.add('%$escaped%');
    }

    final rows = await db.query(
      notesTable,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: filter.inTrash ? 'deleted_at DESC' : filter.sortOrder.sql,
    );
    return rows.map(Note.fromDbMap).toList();
  }

  /// Todas as notas do usuário, inclusive as pendentes de exclusão.
  /// Usado pela sincronização.
  Future<List<Note>> getAllNotes(String uid) async {
    final db = await database;
    final rows =
        await db.query(notesTable, where: 'uid = ?', whereArgs: [uid]);
    return rows.map(Note.fromDbMap).toList();
  }

  Future<List<Note>> getPendingNotes(String uid) async {
    final db = await database;
    final rows = await db.query(
      notesTable,
      where: 'uid = ? AND sync_status != ?',
      whereArgs: [uid, SyncStatus.synced.name],
    );
    return rows.map(Note.fromDbMap).toList();
  }

  /// Remove fisicamente a nota do SQLite.
  Future<void> deleteNote(String id) async {
    final db = await database;
    await db.delete(notesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateNoteSyncStatus(
    String id,
    SyncStatus status, {
    required int expectedUpdatedAt,
  }) async {
    final db = await database;
    // Só marca como sincronizada se a nota não mudou durante o envio.
    await db.update(
      notesTable,
      {'sync_status': status.name},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, expectedUpdatedAt],
    );
  }

  Future<List<Note>> getNotesByCategory(String uid, String categoryId) async {
    final db = await database;
    final rows = await db.query(
      notesTable,
      where: 'uid = ? AND category_id = ? AND sync_status != ?',
      whereArgs: [uid, categoryId, SyncStatus.pendingDelete.name],
    );
    return rows.map(Note.fromDbMap).toList();
  }

  Future<int> countPending(String uid) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM $notesTable WHERE uid = ? AND sync_status != ?) +
        (SELECT COUNT(*) FROM $categoriesTable WHERE uid = ? AND sync_status != ?)
        AS total
    ''', [uid, SyncStatus.synced.name, uid, SyncStatus.synced.name]);
    return (result.first['total'] as int?) ?? 0;
  }

  // ===========================================================================
  // Categorias
  // ===========================================================================

  Future<void> upsertCategory(Category category) async {
    final db = await database;
    await db.insert(categoriesTable, category.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> upsertCategories(Iterable<Category> categories) async {
    final db = await database;
    final batch = db.batch();
    for (final c in categories) {
      batch.insert(categoriesTable, c.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Categorias visíveis (sem as pendentes de exclusão), em ordem alfabética.
  Future<List<Category>> getCategories(String uid) async {
    final db = await database;
    final rows = await db.query(
      categoriesTable,
      where: 'uid = ? AND sync_status != ?',
      whereArgs: [uid, SyncStatus.pendingDelete.name],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromDbMap).toList();
  }

  Future<List<Category>> getAllCategories(String uid) async {
    final db = await database;
    final rows =
        await db.query(categoriesTable, where: 'uid = ?', whereArgs: [uid]);
    return rows.map(Category.fromDbMap).toList();
  }

  Future<List<Category>> getPendingCategories(String uid) async {
    final db = await database;
    final rows = await db.query(
      categoriesTable,
      where: 'uid = ? AND sync_status != ?',
      whereArgs: [uid, SyncStatus.synced.name],
    );
    return rows.map(Category.fromDbMap).toList();
  }

  Future<void> deleteCategory(String id) async {
    final db = await database;
    await db.delete(categoriesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCategorySyncStatus(
    String id,
    SyncStatus status, {
    required int expectedUpdatedAt,
  }) async {
    final db = await database;
    await db.update(
      categoriesTable,
      {'sync_status': status.name},
      where: 'id = ? AND updated_at = ?',
      whereArgs: [id, expectedUpdatedAt],
    );
  }
}
