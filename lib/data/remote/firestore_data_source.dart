import 'dart:async';

import 'package:bloco_de_nota_turma_a/data/remote/remote_data_source.dart';
import 'package:bloco_de_nota_turma_a/data/remote/remote_exception.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Implementação de [RemoteDataSource] usando o Cloud Firestore.
///
/// Estrutura no Firestore (cada usuário só acessa a própria subárvore,
/// conforme `firestore.rules`):
///
/// ```
/// users/{uid}/notes/{noteId}
/// users/{uid}/categories/{categoryId}
/// ```
class FirestoreDataSource implements RemoteDataSource {
  final FirebaseFirestore _firestore;
  final Duration timeout;

  FirestoreDataSource(
    this._firestore, {
    this.timeout = const Duration(seconds: 10),
  });

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _firestore.collection('users').doc(uid).collection('notes');

  CollectionReference<Map<String, dynamic>> _categories(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  /// Executa a operação com limite de tempo e converte qualquer erro em
  /// [RemoteException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } catch (e) {
      throw RemoteException.from(e);
    }
  }

  // Lê sempre do servidor: se estiver offline a leitura falha em vez de
  // devolver um cache possivelmente desatualizado (o cache local é o SQLite).
  static const _serverOnly = GetOptions(source: Source.server);

  @override
  Future<List<Note>> fetchNotes(String uid) => _guard(() async {
        final snapshot = await _notes(uid).get(_serverOnly);
        return snapshot.docs.map((d) => Note.fromFirestore(d.data())).toList();
      });

  @override
  Future<void> upsertNote(Note note) => _guard(() {
        return _notes(note.uid).doc(note.id).set({
          ...note.toFirestore(),
          'serverUpdatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<void> deleteNote(String uid, String noteId) =>
      _guard(() => _notes(uid).doc(noteId).delete());

  @override
  Future<List<Category>> fetchCategories(String uid) => _guard(() async {
        final snapshot = await _categories(uid).get(_serverOnly);
        return snapshot.docs
            .map((d) => Category.fromFirestore(d.data()))
            .toList();
      });

  @override
  Future<void> upsertCategory(Category category) => _guard(() {
        return _categories(category.uid).doc(category.id).set({
          ...category.toFirestore(),
          'serverUpdatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<void> deleteCategory(String uid, String categoryId) =>
      _guard(() => _categories(uid).doc(categoryId).delete());
}
