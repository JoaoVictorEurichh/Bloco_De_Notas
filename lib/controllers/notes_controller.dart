import 'dart:async';

import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/repositories/category_repository.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/services/connectivity_service.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Controller da tela principal (padrão **Observer** com [ChangeNotifier]).
///
/// Mantém o estado da lista (filtro, pesquisa, categorias) e separa a lógica
/// de apresentação dos widgets. A tela apenas escuta o controller e chama
/// seus métodos.
class NotesController extends ChangeNotifier {
  final String uid;
  final NoteRepository notesRepository;
  final CategoryRepository categoryRepository;
  final SyncService syncService;
  final ConnectivityService? connectivity;

  NotesController({
    required this.uid,
    required this.notesRepository,
    required this.categoryRepository,
    required this.syncService,
    this.connectivity,
  });

  NoteFilter _filter = const NoteFilter();
  NoteFilter get filter => _filter;

  List<Note> _notes = const [];
  List<Note> get notes => _notes;

  List<Category> _categories = const [];
  List<Category> get categories => _categories;

  Map<String, Category> _categoriesById = const {};
  Category? categoryOf(Note note) =>
      note.categoryId == null ? null : _categoriesById[note.categoryId];

  bool _loading = true;
  bool get loading => _loading;

  bool _disposed = false;
  StreamSubscription<bool>? _connectivitySub;
  SyncPhase _lastPhase = SyncPhase.idle;

  bool get isSearching =>
      _filter.searchTerm.trim().isNotEmpty || _filter.categoryId != null;

  Future<void> init() async {
    syncService.addListener(_onSyncChanged);
    _connectivitySub = connectivity?.onStatusChange.listen((online) {
      if (online) syncService.requestSync(uid);
    });

    await notesRepository.purgeExpiredTrash(uid);
    await reload();

    // Primeiro baixa o que existe na nuvem (outra instalação, reinstalação)
    // e só então cria as categorias padrão, se ainda não houver nenhuma.
    await syncService.sync(uid);
    if (await categoryRepository.seedDefaultsIfEmpty(uid)) {
      await reload();
    }
  }

  void _onSyncChanged() {
    final phase = syncService.state.phase;
    final finished = _lastPhase == SyncPhase.syncing &&
        (phase == SyncPhase.success || phase == SyncPhase.error);
    _lastPhase = phase;
    if (finished) unawaited(reload());
  }

  Future<void> reload() async {
    final results = await Future.wait([
      notesRepository.query(uid, _filter),
      categoryRepository.getAll(uid),
    ]);
    if (_disposed) return;
    _notes = results[0] as List<Note>;
    _categories = results[1] as List<Category>;
    _categoriesById = {for (final c in _categories) c.id: c};

    // Se a categoria filtrada foi excluída, volta para "Todas".
    if (_filter.categoryId != null &&
        !_categoriesById.containsKey(_filter.categoryId)) {
      _filter = _filter.copyWith(clearCategory: true);
      _notes = await notesRepository.query(uid, _filter);
      if (_disposed) return;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> setSearchTerm(String term) async {
    _filter = _filter.copyWith(searchTerm: term);
    await reload();
  }

  Future<void> setCategory(String? categoryId) async {
    _filter = categoryId == null
        ? _filter.copyWith(clearCategory: true)
        : _filter.copyWith(categoryId: categoryId);
    await reload();
  }

  Future<void> setSortOrder(NoteSortOrder order) async {
    _filter = _filter.copyWith(sortOrder: order);
    await reload();
  }

  Future<SyncReport> syncNow() => syncService.sync(uid);

  Future<void> moveToTrash(Note note) async {
    await notesRepository.moveToTrash(note);
    await reload();
  }

  Future<void> restore(Note note) async {
    await notesRepository.restore(note);
    await reload();
  }

  @override
  void dispose() {
    _disposed = true;
    syncService.removeListener(_onSyncChanged);
    _connectivitySub?.cancel();
    super.dispose();
  }
}
