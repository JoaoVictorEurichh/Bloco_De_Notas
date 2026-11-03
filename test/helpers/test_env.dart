import 'dart:io';

import 'package:bloco_de_nota_turma_a/data/local/database_helper.dart';
import 'package:bloco_de_nota_turma_a/repositories/category_repository.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_remote_data_source.dart';

/// Relógio controlado manualmente nos testes.
class FakeClock {
  int value = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  int call() => value;
  void advance([Duration d = const Duration(seconds: 1)]) =>
      value += d.inMilliseconds;
}

/// Uma "instalação" do app: banco SQLite próprio (em memória) apontando para
/// a nuvem compartilhada.
class Installation {
  final DatabaseHelper db;
  final SyncService sync;
  final NoteRepository notes;
  final CategoryRepository categories;

  Installation._(this.db, this.sync, this.notes, this.categories);

  factory Installation(FakeRemoteDataSource remote, FakeClock clock) {
    sqfliteFfiInit();
    final db = DatabaseHelper(
      factory: databaseFactoryFfiNoIsolate,
      // Cada instalação tem o seu próprio arquivo, como aparelhos diferentes.
      fileName: '${Directory.systemTemp.createTempSync('notes_test').path}/notes.db',
    );
    final sync = SyncService(db, remote);
    final notes = NoteRepository(db, sync, clock: clock.call);
    final categories =
        CategoryRepository(db, sync, notes, clock: clock.call);
    return Installation._(db, sync, notes, categories);
  }

  Future<void> close() async {
    await sync.idle;
    await db.close();
  }
}
