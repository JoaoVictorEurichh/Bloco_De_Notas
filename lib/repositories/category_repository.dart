import 'package:bloco_de_nota_turma_a/data/local/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:bloco_de_nota_turma_a/utils/text_normalizer.dart';
import 'package:uuid/uuid.dart';

class CategoryException implements Exception {
  final String message;
  const CategoryException(this.message);
  @override
  String toString() => message;
}

/// Repositório de categorias, com a mesma estratégia offline-first do
/// [NoteRepository].
class CategoryRepository {
  /// Categorias criadas automaticamente no primeiro acesso. Os ids são fixos
  /// para que duas instalações diferentes não criem categorias duplicadas.
  static const defaults = [
    ('default-estudos', 'Estudos', 0),
    ('default-trabalho', 'Trabalho', 1),
    ('default-pessoal', 'Pessoal', 2),
  ];

  final DatabaseHelper _db;
  final SyncService _sync;
  final NoteRepository _notes;
  final Uuid _uuid;
  final int Function() _now;

  CategoryRepository(
    this._db,
    this._sync,
    this._notes, {
    Uuid uuid = const Uuid(),
    int Function()? clock,
  })  : _uuid = uuid,
        _now = clock ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  Future<List<Category>> getAll(String uid) => _db.getCategories(uid);

  /// Cria as categorias padrão caso o usuário ainda não tenha nenhuma.
  Future<bool> seedDefaultsIfEmpty(String uid) async {
    final existing = await _db.getAllCategories(uid);
    if (existing.isNotEmpty) return false;
    final now = _now();
    await _db.upsertCategories([
      for (final (id, name, color) in defaults)
        Category(
          id: id,
          uid: uid,
          name: name,
          colorIndex: color,
          updatedAt: now,
          syncStatus: SyncStatus.pendingUpsert,
        ),
    ]);
    _sync.requestSync(uid);
    return true;
  }

  Future<Category> create(String uid, String name, {int? colorIndex}) async {
    final trimmed = await _validateName(uid, name);
    final all = await _db.getCategories(uid);
    final category = Category(
      id: _uuid.v4(),
      uid: uid,
      name: trimmed,
      colorIndex: colorIndex ?? all.length,
      updatedAt: _now(),
      syncStatus: SyncStatus.pendingUpsert,
    );
    await _db.upsertCategory(category);
    _sync.requestSync(uid);
    return category;
  }

  Future<Category> rename(Category category, String newName) async {
    final trimmed =
        await _validateName(category.uid, newName, ignoreId: category.id);
    final updated = category.copyWith(
      name: trimmed,
      updatedAt: _now(),
      syncStatus: SyncStatus.pendingUpsert,
    );
    await _db.upsertCategory(updated);
    _sync.requestSync(category.uid);
    return updated;
  }

  /// Exclui a categoria. As notas que a usavam ficam "Sem categoria".
  Future<void> delete(Category category) async {
    await _notes.clearCategory(category.uid, category.id);
    await _db.upsertCategory(category.copyWith(
      updatedAt: _now(),
      syncStatus: SyncStatus.pendingDelete,
    ));
    _sync.requestSync(category.uid);
  }

  Future<String> _validateName(String uid, String name,
      {String? ignoreId}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const CategoryException('Informe o nome da categoria.');
    }
    if (trimmed.length > 40) {
      throw const CategoryException('Use no máximo 40 caracteres.');
    }
    final normalized = normalizeForSearch(trimmed);
    final all = await _db.getCategories(uid);
    final duplicated = all.any(
        (c) => c.id != ignoreId && normalizeForSearch(c.name) == normalized);
    if (duplicated) {
      throw const CategoryException('Já existe uma categoria com esse nome.');
    }
    return trimmed;
  }
}
