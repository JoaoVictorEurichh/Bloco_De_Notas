import 'package:bloco_de_nota_turma_a/data/remote/firestore_data_source.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreDataSource source;

  const note = Note(
    id: 'n1',
    uid: 'u1',
    title: 'Título',
    content: 'Conteúdo',
    categoryId: 'c1',
    createdAt: 100,
    updatedAt: 200,
  );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    source = FirestoreDataSource(firestore);
  });

  test('grava a nota em users/{uid}/notes/{id}', () async {
    await source.upsertNote(note);
    final doc = await firestore.doc('users/u1/notes/n1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['title'], 'Título');
    expect(doc.data()!['uid'], 'u1');
    expect(doc.data()!['categoryId'], 'c1');
    expect(doc.data()!.containsKey('serverUpdatedAt'), isTrue);
  });

  test('lê somente as notas do usuário informado', () async {
    await source.upsertNote(note);
    await source.upsertNote(const Note(
        id: 'n2', uid: 'u2', title: 'x', content: '', createdAt: 1, updatedAt: 1));

    final notes = await source.fetchNotes('u1');
    expect(notes.map((n) => n.id), ['n1']);
    expect(notes.single.categoryId, 'c1');
  });

  test('exclui a nota', () async {
    await source.upsertNote(note);
    await source.deleteNote('u1', 'n1');
    expect(await source.fetchNotes('u1'), isEmpty);
  });

  test('grava e lê categorias', () async {
    await source.upsertCategory(const Category(
        id: 'c1', uid: 'u1', name: 'Estudos', updatedAt: 1, colorIndex: 2));
    final categories = await source.fetchCategories('u1');
    expect(categories.single.name, 'Estudos');
    expect(categories.single.colorIndex, 2);

    await source.deleteCategory('u1', 'c1');
    expect(await source.fetchCategories('u1'), isEmpty);
  });
}
