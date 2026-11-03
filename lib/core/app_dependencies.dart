import 'package:bloco_de_nota_turma_a/data/local/database_helper.dart';
import 'package:bloco_de_nota_turma_a/data/remote/firestore_data_source.dart';
import 'package:bloco_de_nota_turma_a/data/remote/remote_data_source.dart';
import 'package:bloco_de_nota_turma_a/repositories/category_repository.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:bloco_de_nota_turma_a/services/connectivity_service.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// *Composition root*: cria e conecta todas as dependências do app em um
/// único lugar (injeção de dependência manual). As telas recebem os objetos
/// prontos via [AppScope] em vez de instanciá-los diretamente.
class AppDependencies {
  final AuthService? auth;
  final DatabaseHelper database;
  final SyncService sync;
  final NoteRepository notes;
  final CategoryRepository categories;
  final ConnectivityService? connectivity;

  /// `false` quando o Firebase não pôde ser inicializado.
  final bool firebaseReady;

  AppDependencies({
    required this.auth,
    required this.database,
    required this.sync,
    required this.notes,
    required this.categories,
    required this.connectivity,
    required this.firebaseReady,
  });

  factory AppDependencies.create({required bool firebaseReady}) {
    final database = DatabaseHelper.instance;
    RemoteDataSource? remote;
    if (firebaseReady) {
      final firestore = FirebaseFirestore.instance;
      // O cache offline do próprio Firestore é desligado: o SQLite é a única
      // cópia local e a sincronização é controlada pelo SyncService.
      firestore.settings = const Settings(persistenceEnabled: false);
      remote = FirestoreDataSource(firestore);
    }
    final sync = SyncService(database, remote);
    final notes = NoteRepository(database, sync);
    return AppDependencies(
      auth: firebaseReady ? AuthService() : null,
      database: database,
      sync: sync,
      notes: notes,
      categories: CategoryRepository(database, sync, notes),
      connectivity: ConnectivityService(),
      firebaseReady: firebaseReady,
    );
  }
}

/// Disponibiliza [AppDependencies] para a árvore de widgets.
class AppScope extends InheritedWidget {
  final AppDependencies deps;

  const AppScope({super.key, required this.deps, required super.child});

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope não encontrado na árvore de widgets');
    return scope!.deps;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => deps != oldWidget.deps;
}
