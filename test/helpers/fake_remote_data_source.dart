import 'package:bloco_de_nota_turma_a/data/remote/remote_data_source.dart';
import 'package:bloco_de_nota_turma_a/data/remote/remote_exception.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';

/// "Nuvem" em memória que simula o Firestore, inclusive falhas de conexão e
/// a regra de segurança "cada usuário só acessa os próprios dados".
class FakeRemoteDataSource implements RemoteDataSource {
  /// uid -> (id -> nota)
  final Map<String, Map<String, Note>> notes = {};
  final Map<String, Map<String, Category>> categories = {};

  bool offline = false;

  /// Simula o usuário autenticado. `null` desativa a verificação.
  String? authenticatedUid;

  int writes = 0;

  void _check(String uid) {
    if (offline) throw const RemoteException(RemoteErrorKind.offline);
    if (authenticatedUid != null && authenticatedUid != uid) {
      throw const RemoteException(RemoteErrorKind.permissionDenied);
    }
  }

  @override
  Future<List<Note>> fetchNotes(String uid) async {
    _check(uid);
    return notes[uid]?.values.toList() ?? [];
  }

  @override
  Future<void> upsertNote(Note note) async {
    _check(note.uid);
    writes++;
    // Como no Firestore, o que é guardado não tem estado de sincronização.
    notes.putIfAbsent(note.uid, () => {})[note.id] =
        Note.fromFirestore(note.toFirestore());
  }

  @override
  Future<void> deleteNote(String uid, String noteId) async {
    _check(uid);
    writes++;
    notes[uid]?.remove(noteId);
  }

  @override
  Future<List<Category>> fetchCategories(String uid) async {
    _check(uid);
    return categories[uid]?.values.toList() ?? [];
  }

  @override
  Future<void> upsertCategory(Category category) async {
    _check(category.uid);
    writes++;
    categories.putIfAbsent(category.uid, () => {})[category.id] =
        Category.fromFirestore(category.toFirestore());
  }

  @override
  Future<void> deleteCategory(String uid, String categoryId) async {
    _check(uid);
    writes++;
    categories[uid]?.remove(categoryId);
  }
}
