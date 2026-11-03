import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';

/// Contrato da fonte de dados remota.
///
/// O [SyncService] depende desta abstração e não do Firestore diretamente
/// (inversão de dependência). Isso permite trocar a implementação nos testes
/// por uma fake que simula falhas de rede.
///
/// Todas as operações lançam `RemoteException` em caso de falha.
abstract interface class RemoteDataSource {
  Future<List<Note>> fetchNotes(String uid);
  Future<void> upsertNote(Note note);
  Future<void> deleteNote(String uid, String noteId);

  Future<List<Category>> fetchCategories(String uid);
  Future<void> upsertCategory(Category category);
  Future<void> deleteCategory(String uid, String categoryId);
}
