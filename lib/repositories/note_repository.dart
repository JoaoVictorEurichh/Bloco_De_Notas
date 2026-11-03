import 'package:bloco_de_nota_turma_a/data/local/database_helper.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Repositório de notas (padrão **Repository**).
///
/// É a única porta de entrada das telas para os dados de notas. Implementa a
/// estratégia *offline-first*:
///
/// 1. toda operação é gravada primeiro no SQLite, marcada como pendente;
/// 2. em seguida é solicitada uma sincronização com o Firestore;
/// 3. se não houver conexão, a nota continua pendente e é enviada depois.
///
/// Assim a interface responde imediatamente e nada se perde sem internet.
class NoteRepository {
  /// Tempo que uma nota permanece na lixeira antes da exclusão definitiva.
  static const trashRetention = Duration(days: 30);

  final DatabaseHelper _db;
  final SyncService _sync;
  final Uuid _uuid;
  final int Function() _now;

  NoteRepository(
    this._db,
    this._sync, {
    Uuid uuid = const Uuid(),
    int Function()? clock,
  })  : _uuid = uuid,
        _now = clock ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  Future<List<Note>> query(String uid, NoteFilter filter) =>
      _db.queryNotes(uid, filter);

  Future<Note?> getById(String id) => _db.getNote(id);

  Future<Note> create({
    required String uid,
    required String title,
    required String content,
    String? categoryId,
  }) async {
    final now = _now();
    final note = Note(
      id: _uuid.v4(),
      uid: uid,
      title: title,
      content: content,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingUpsert,
    );
    await _save(note);
    return note;
  }

  Future<Note> update(
    Note note, {
    required String title,
    required String content,
    String? categoryId,
  }) async {
    final updated = note.copyWith(
      title: title,
      content: content,
      categoryId: categoryId,
      clearCategory: categoryId == null,
      updatedAt: _now(),
      syncStatus: SyncStatus.pendingUpsert,
    );
    await _save(updated);
    return updated;
  }

  /// Lixeira: exclusão temporária. A nota some da lista principal, mas pode
  /// ser restaurada. A marcação também é sincronizada com o Firestore.
  Future<void> moveToTrash(Note note) async {
    final now = _now();
    await _save(note.copyWith(
      deletedAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.pendingUpsert,
    ));
  }

  Future<void> restore(Note note) async {
    await _save(note.copyWith(
      clearDeletedAt: true,
      updatedAt: _now(),
      syncStatus: SyncStatus.pendingUpsert,
    ));
  }

  /// Exclusão definitiva. A nota é ocultada e marcada como
  /// [SyncStatus.pendingDelete]; o registro só é apagado do SQLite depois de
  /// ser apagado também no Firestore.
  Future<void> deletePermanently(Note note) async {
    await _markPendingDelete(note);
    _sync.requestSync(note.uid);
  }

  Future<int> emptyTrash(String uid) async {
    final trash = await _db.queryNotes(uid, const NoteFilter(inTrash: true));
    for (final note in trash) {
      await _markPendingDelete(note);
    }
    if (trash.isNotEmpty) _sync.requestSync(uid);
    return trash.length;
  }

  /// Remove definitivamente as notas que estão na lixeira há mais de
  /// [trashRetention].
  Future<int> purgeExpiredTrash(String uid) async {
    final limit = _now() - trashRetention.inMilliseconds;
    final trash = await _db.queryNotes(uid, const NoteFilter(inTrash: true));
    final expired = trash.where((n) => n.deletedAt! < limit).toList();
    for (final note in expired) {
      await _markPendingDelete(note);
    }
    return expired.length;
  }

  /// Remove a categoria das notas que a utilizavam.
  Future<void> clearCategory(String uid, String categoryId) async {
    final notes = await _db.getNotesByCategory(uid, categoryId);
    final now = _now();
    for (final note in notes) {
      await _db.upsertNote(note.copyWith(
        clearCategory: true,
        updatedAt: now,
        syncStatus: SyncStatus.pendingUpsert,
      ));
    }
  }

  Future<void> _markPendingDelete(Note note) async {
    // Se a nota nunca chegou à nuvem não há o que apagar remotamente,
    // mas o SyncService trata os dois casos da mesma forma.
    await _db.upsertNote(note.copyWith(
      updatedAt: _now(),
      syncStatus: SyncStatus.pendingDelete,
    ));
  }

  Future<void> _save(Note note) async {
    await _db.upsertNote(note);
    _sync.requestSync(note.uid);
  }
}
