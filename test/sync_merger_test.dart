import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/services/sync_merger.dart';
import 'package:flutter_test/flutter_test.dart';

Note note(String id,
        {int updatedAt = 1,
        SyncStatus status = SyncStatus.synced,
        String title = 't'}) =>
    Note(
      id: id,
      uid: 'u1',
      title: title,
      content: 'c',
      createdAt: 1,
      updatedAt: updatedAt,
      syncStatus: status,
    );

void main() {
  const merger = SyncMerger();

  test('nota que só existe na nuvem é baixada', () {
    final plan = merger.plan<Note>(local: [], remote: [note('a')]);
    expect(plan.toSaveLocal.map((n) => n.id), ['a']);
    expect(plan.toUpload, isEmpty);
  });

  test('nota pendente que não existe na nuvem é enviada', () {
    final plan = merger.plan<Note>(
        local: [note('a', status: SyncStatus.pendingUpsert)], remote: []);
    expect(plan.toUpload.map((n) => n.id), ['a']);
  });

  test('nota sincronizada apagada em outro aparelho é removida localmente', () {
    final plan = merger.plan<Note>(local: [note('a')], remote: []);
    expect(plan.toDeleteLocal, ['a']);
  });

  test('nota sincronizada alterada em outro aparelho é atualizada', () {
    final plan = merger.plan<Note>(
      local: [note('a', updatedAt: 1)],
      remote: [note('a', updatedAt: 5, title: 'novo')],
    );
    expect(plan.toSaveLocal.single.title, 'novo');
  });

  test('nota idêntica nos dois lados não gera ação', () {
    final plan = merger.plan<Note>(local: [note('a')], remote: [note('a')]);
    expect(plan.isEmpty, isTrue);
  });

  test('conflito: alteração local mais recente vence (last write wins)', () {
    final plan = merger.plan<Note>(
      local: [note('a', updatedAt: 10, status: SyncStatus.pendingUpsert)],
      remote: [note('a', updatedAt: 5)],
    );
    expect(plan.toUpload.single.id, 'a');
    expect(plan.toSaveLocal, isEmpty);
  });

  test('conflito: alteração remota mais recente vence', () {
    final plan = merger.plan<Note>(
      local: [note('a', updatedAt: 5, status: SyncStatus.pendingUpsert)],
      remote: [note('a', updatedAt: 10, title: 'remota')],
    );
    expect(plan.toUpload, isEmpty);
    expect(plan.toSaveLocal.single.title, 'remota');
  });

  test('exclusão pendente é replicada na nuvem', () {
    final plan = merger.plan<Note>(
      local: [note('a', status: SyncStatus.pendingDelete)],
      remote: [note('a')],
    );
    expect(plan.toDeleteRemote, ['a']);
    expect(plan.toSaveLocal, isEmpty);
  });
}
