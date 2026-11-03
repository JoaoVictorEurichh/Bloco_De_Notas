import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_remote_data_source.dart';
import 'helpers/test_env.dart';

void main() {
  late FakeRemoteDataSource remote;
  late FakeClock clock;
  late Installation app;

  setUp(() {
    remote = FakeRemoteDataSource()..offline = true;
    clock = FakeClock();
    app = Installation(remote, clock);
  });

  tearDown(() => app.close());

  Future<void> seed() async {
    await app.notes.create(
        uid: 'u1',
        title: 'Prova de Cálculo',
        content: 'Estudar derivadas',
        categoryId: 'estudos');
    clock.advance();
    await app.notes.create(
        uid: 'u1',
        title: 'Reunião',
        content: 'Pauta: orçamento 50% maior',
        categoryId: 'trabalho');
    clock.advance();
    await app.notes.create(
        uid: 'u1', title: 'Mercado', content: 'Comprar café');
    clock.advance();
    // Nota de outro usuário no mesmo aparelho: nunca deve aparecer para u1.
    await app.notes.create(
        uid: 'u2', title: 'Segredo', content: 'Cálculo do u2');
  }

  test('CRUD local: cria, consulta, edita e exclui', () async {
    final created =
        await app.notes.create(uid: 'u1', title: 'A', content: 'texto');
    expect((await app.notes.getById(created.id))!.title, 'A');

    clock.advance();
    await app.notes.update(created, title: 'B', content: 'novo');
    final updated = (await app.notes.getById(created.id))!;
    expect(updated.title, 'B');
    expect(updated.updatedAt, greaterThan(created.updatedAt));
    expect(updated.syncStatus, SyncStatus.pendingUpsert);

    await app.notes.deletePermanently(updated);
    final visible = await app.notes.query('u1', const NoteFilter());
    expect(visible, isEmpty);
  });

  test('pesquisa por título e conteúdo, sem diferenciar acentos', () async {
    await seed();
    Future<List<String>> search(String term) async =>
        (await app.notes.query('u1', NoteFilter(searchTerm: term)))
            .map((n) => n.title)
            .toList();

    expect(await search('calculo'), ['Prova de Cálculo']); // título
    expect(await search('CAFÉ'), ['Mercado']); // conteúdo
    expect(await search('reuniao'), ['Reunião']);
    expect(await search('50%'), ['Reunião']); // curinga tratado como literal
    expect(await search('%'), ['Reunião']);
    expect(await search('inexistente'), isEmpty);
  });

  test('pesquisa não retorna notas de outro usuário', () async {
    await seed();
    final result =
        await app.notes.query('u1', const NoteFilter(searchTerm: 'segredo'));
    expect(result, isEmpty);
  });

  test('filtra por categoria e combina com a pesquisa', () async {
    await seed();
    final estudos = await app.notes
        .query('u1', const NoteFilter(categoryId: 'estudos'));
    expect(estudos.map((n) => n.title), ['Prova de Cálculo']);

    final none = await app.notes.query(
        'u1', const NoteFilter(categoryId: 'estudos', searchTerm: 'café'));
    expect(none, isEmpty);
  });

  test('ordena por data de criação e atualização', () async {
    await seed();
    final notes = await app.notes.query('u1', const NoteFilter());
    // Edita a mais antiga: ela passa a ser a última atualizada.
    final oldest = notes.last;
    clock.advance();
    await app.notes.update(oldest, title: oldest.title, content: 'editado');

    Future<List<String>> titles(NoteSortOrder order) async =>
        (await app.notes.query('u1', NoteFilter(sortOrder: order)))
            .map((n) => n.title)
            .toList();

    expect(await titles(NoteSortOrder.updatedDesc),
        ['Prova de Cálculo', 'Mercado', 'Reunião']);
    expect(await titles(NoteSortOrder.createdDesc),
        ['Mercado', 'Reunião', 'Prova de Cálculo']);
    expect(await titles(NoteSortOrder.createdAsc),
        ['Prova de Cálculo', 'Reunião', 'Mercado']);
    expect(await titles(NoteSortOrder.titleAsc),
        ['Mercado', 'Prova de Cálculo', 'Reunião']);
  });

  test('lixeira: mover, restaurar e expirar após 30 dias', () async {
    final note =
        await app.notes.create(uid: 'u1', title: 'Temp', content: '...');
    await app.notes.moveToTrash(note);

    expect(await app.notes.query('u1', const NoteFilter()), isEmpty);
    final trash =
        await app.notes.query('u1', const NoteFilter(inTrash: true));
    expect(trash.single.id, note.id);

    await app.notes.restore(trash.single);
    expect((await app.notes.query('u1', const NoteFilter())).single.id,
        note.id);

    await app.notes.moveToTrash(
        (await app.notes.getById(note.id))!);
    clock.advance(const Duration(days: 31));
    expect(await app.notes.purgeExpiredTrash('u1'), 1);
    expect(await app.notes.query('u1', const NoteFilter(inTrash: true)),
        isEmpty);
  });

  test('excluir categoria deixa as notas sem categoria', () async {
    final category = await app.categories.create('u1', 'Faculdade');
    final note = await app.notes.create(
        uid: 'u1', title: 'TCC', content: '', categoryId: category.id);

    await app.categories.delete(category);

    expect(await app.categories.getAll('u1'), isEmpty);
    expect((await app.notes.getById(note.id))!.categoryId, isNull);
  });

  test('não permite categorias duplicadas', () async {
    await app.categories.create('u1', 'Estudos');
    expect(() => app.categories.create('u1', ' estudos '),
        throwsA(isA<Object>()));
  });
}
