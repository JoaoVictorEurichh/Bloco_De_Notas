import 'package:bloco_de_nota_turma_a/data/remote/remote_exception.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_remote_data_source.dart';
import 'helpers/test_env.dart';

void main() {
  late FakeRemoteDataSource cloud;
  late FakeClock clock;
  late Installation phone;
  late Installation tablet;

  setUp(() {
    cloud = FakeRemoteDataSource();
    clock = FakeClock();
    phone = Installation(cloud, clock);
    tablet = Installation(cloud, clock);
  });

  tearDown(() async {
    await phone.close();
    await tablet.close();
  });

  test('nota criada é enviada ao Firestore e marcada como sincronizada',
      () async {
    final note =
        await phone.notes.create(uid: 'u1', title: 'Olá', content: 'mundo');
    final report = await phone.sync.sync('u1');

    expect(report.ok, isTrue);
    expect(cloud.notes['u1']![note.id]!.title, 'Olá');
    expect((await phone.notes.getById(note.id))!.syncStatus,
        SyncStatus.synced);
    expect(phone.sync.state.phase, SyncPhase.success);
    expect(phone.sync.state.pendingCount, 0);
  });

  test('sem conexão: nota fica pendente e é enviada quando a rede volta',
      () async {
    cloud.offline = true;
    final note =
        await phone.notes.create(uid: 'u1', title: 'Offline', content: '');
    final report = await phone.sync.sync('u1');

    expect(report.ok, isFalse);
    expect(report.failures.first.kind, RemoteErrorKind.offline);
    expect(phone.sync.state.phase, SyncPhase.error);
    expect(phone.sync.state.pendingCount, 1);
    expect((await phone.notes.getById(note.id))!.syncStatus,
        SyncStatus.pendingUpsert);
    expect(cloud.notes['u1'], isNull);

    cloud.offline = false;
    expect((await phone.sync.sync('u1')).ok, isTrue);
    expect(cloud.notes['u1']![note.id], isNotNull);
    expect(phone.sync.state.pendingCount, 0);
  });

  test('outra instalação recupera as notas e categorias da nuvem', () async {
    final category = await phone.categories.create('u1', 'Faculdade');
    await phone.notes.create(
        uid: 'u1',
        title: 'Trabalho de BD',
        content: 'Entregar sexta',
        categoryId: category.id);
    await phone.sync.sync('u1');

    // "Reinstalação": um aparelho com banco vazio.
    await tablet.sync.sync('u1');
    final notes = await tablet.notes.query('u1', const NoteFilter());
    expect(notes.single.title, 'Trabalho de BD');
    expect(notes.single.categoryId, category.id);
    expect((await tablet.categories.getAll('u1')).single.name, 'Faculdade');

    // A pesquisa funciona sobre os dados baixados.
    final found = await tablet.notes
        .query('u1', const NoteFilter(searchTerm: 'sexta'));
    expect(found, hasLength(1));
  });

  test('edição em um aparelho chega ao outro', () async {
    final note =
        await phone.notes.create(uid: 'u1', title: 'v1', content: '');
    await phone.sync.sync('u1');
    await tablet.sync.sync('u1');

    clock.advance();
    final onTablet = (await tablet.notes.getById(note.id))!;
    await tablet.notes.update(onTablet, title: 'v2', content: 'editado');
    await tablet.sync.sync('u1');

    await phone.sync.sync('u1');
    expect((await phone.notes.getById(note.id))!.title, 'v2');
  });

  test('conflito resolvido pela alteração mais recente', () async {
    final note =
        await phone.notes.create(uid: 'u1', title: 'base', content: '');
    await phone.sync.sync('u1');
    await tablet.sync.sync('u1');

    cloud.offline = true;
    clock.advance();
    await phone.notes.update(note, title: 'celular', content: '');
    clock.advance();
    final onTablet = (await tablet.notes.getById(note.id))!;
    await tablet.notes.update(onTablet, title: 'tablet', content: '');
    await phone.sync.idle;
    await tablet.sync.idle;

    cloud.offline = false;
    await tablet.sync.sync('u1'); // mais recente
    await phone.sync.sync('u1'); // mais antiga: perde

    expect(cloud.notes['u1']![note.id]!.title, 'tablet');
    expect((await phone.notes.getById(note.id))!.title, 'tablet');
  });

  test('lixeira e exclusão definitiva são replicadas', () async {
    final note =
        await phone.notes.create(uid: 'u1', title: 'apagar', content: '');
    await phone.sync.sync('u1');
    await tablet.sync.sync('u1');

    await phone.notes.moveToTrash(note);
    await phone.sync.sync('u1');
    expect(cloud.notes['u1']![note.id]!.deletedAt, isNotNull);

    await tablet.sync.sync('u1');
    expect(await tablet.notes.query('u1', const NoteFilter()), isEmpty);
    final tabletTrash =
        await tablet.notes.query('u1', const NoteFilter(inTrash: true));
    expect(tabletTrash, hasLength(1));

    await tablet.notes.deletePermanently(tabletTrash.single);
    await tablet.sync.sync('u1');
    expect(cloud.notes['u1']!.containsKey(note.id), isFalse);
    expect(await tablet.notes.getById(note.id), isNull);

    await phone.sync.sync('u1');
    expect(await phone.notes.getById(note.id), isNull);
  });

  test('acesso negado pelas regras é reportado e nada é perdido', () async {
    cloud.authenticatedUid = 'outro-usuario';
    final note =
        await phone.notes.create(uid: 'u1', title: 'privada', content: '');
    final report = await phone.sync.sync('u1');

    expect(report.ok, isFalse);
    expect(report.failures.first.kind, RemoteErrorKind.permissionDenied);
    expect(await phone.notes.getById(note.id), isNotNull);
  });

  test('categorias padrão são criadas uma única vez', () async {
    await phone.sync.sync('u1');
    expect(await phone.categories.seedDefaultsIfEmpty('u1'), isTrue);
    await phone.sync.sync('u1');

    await tablet.sync.sync('u1');
    expect(await tablet.categories.seedDefaultsIfEmpty('u1'), isFalse);
    expect((await tablet.categories.getAll('u1')).map((c) => c.name),
        ['Estudos', 'Pessoal', 'Trabalho']);
  });
}
