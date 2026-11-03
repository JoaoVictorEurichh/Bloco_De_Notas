import 'dart:async';

import 'package:bloco_de_nota_turma_a/data/local/database_helper.dart';
import 'package:bloco_de_nota_turma_a/data/remote/remote_data_source.dart';
import 'package:bloco_de_nota_turma_a/data/remote/remote_exception.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/services/sync_merger.dart';
import 'package:flutter/foundation.dart';

enum SyncPhase { idle, syncing, success, error }

/// Estado observável da sincronização, exibido na interface.
@immutable
class SyncState {
  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final int pendingCount;
  final RemoteException? error;

  const SyncState({
    this.phase = SyncPhase.idle,
    this.lastSyncedAt,
    this.pendingCount = 0,
    this.error,
  });

  bool get isSyncing => phase == SyncPhase.syncing;
}

/// Resumo de uma execução da sincronização.
class SyncReport {
  int uploaded = 0;
  int downloaded = 0;
  int deletedRemote = 0;
  int deletedLocal = 0;
  final List<RemoteException> failures = [];

  bool get ok => failures.isEmpty;
}

/// Sincroniza o SQLite com o Firestore (padrão **Observer** via
/// [ChangeNotifier]: as telas escutam [state]).
///
/// Fluxo de `sync(uid)`:
/// 1. Baixa notas e categorias do Firestore (se falhar, nada local é perdido).
/// 2. Compara com o SQLite usando o [SyncMerger].
/// 3. Aplica no SQLite o que veio da nuvem.
/// 4. Envia ao Firestore o que está pendente no aparelho; cada item enviado
///    com sucesso é marcado como `synced`. Itens que falharem continuam
///    pendentes e serão reenviados na próxima sincronização.
///
/// Chamadas concorrentes são agrupadas: se uma sincronização já estiver em
/// andamento, uma nova rodada é agendada para logo após o término.
class SyncService extends ChangeNotifier {
  final DatabaseHelper _db;
  final RemoteDataSource? _remote;
  final SyncMerger _merger;

  SyncService(this._db, this._remote, {SyncMerger merger = const SyncMerger()})
      : _merger = merger;

  SyncState _state = const SyncState();
  SyncState get state => _state;

  Future<SyncReport>? _running;
  bool _rerunRequested = false;

  void _emit(SyncState s) {
    _state = s;
    notifyListeners();
  }

  /// Atualiza apenas o contador de pendências exibido na interface.
  Future<void> refreshPendingCount(String uid) async {
    final pending = await _db.countPending(uid);
    _emit(SyncState(
      phase: _state.phase,
      lastSyncedAt: _state.lastSyncedAt,
      pendingCount: pending,
      error: _state.error,
    ));
  }

  /// Completa quando não houver sincronização em andamento.
  Future<void> get idle async {
    while (_running != null) {
      await _running;
    }
  }

  /// Solicita uma sincronização sem aguardar nem lançar erros.
  void requestSync(String uid) {
    unawaited(sync(uid));
  }

  /// Executa a sincronização completa. Nunca lança exceção: os erros ficam
  /// registrados no [SyncReport] e em [state].
  Future<SyncReport> sync(String uid) {
    if (_running != null) {
      _rerunRequested = true;
      return _running!;
    }
    final future = _runLoop(uid);
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<SyncReport> _runLoop(String uid) async {
    SyncReport report;
    do {
      _rerunRequested = false;
      report = await _syncOnce(uid);
    } while (_rerunRequested);
    return report;
  }

  Future<SyncReport> _syncOnce(String uid) async {
    final report = SyncReport();
    final remote = _remote;

    _emit(SyncState(
      phase: SyncPhase.syncing,
      lastSyncedAt: _state.lastSyncedAt,
      pendingCount: await _db.countPending(uid),
    ));

    if (remote == null) {
      report.failures.add(const RemoteException(RemoteErrorKind.notConfigured));
    } else {
      try {
        await _syncCategories(uid, remote, report);
        await _syncNotes(uid, remote, report);
      } on RemoteException catch (e) {
        // Falha ao baixar os dados: a sincronização é abortada sem alterar
        // nada no SQLite.
        report.failures.add(e);
      } catch (e) {
        report.failures.add(RemoteException.from(e));
      }
    }

    final pending = await _db.countPending(uid);
    _emit(SyncState(
      phase: report.ok ? SyncPhase.success : SyncPhase.error,
      lastSyncedAt: report.ok ? DateTime.now() : _state.lastSyncedAt,
      pendingCount: pending,
      error: report.ok ? null : report.failures.first,
    ));
    if (!report.ok) {
      debugPrint('Sincronização falhou: ${report.failures.first}');
    }
    return report;
  }

  Future<void> _syncNotes(
      String uid, RemoteDataSource remote, SyncReport report) async {
    final remoteNotes = await remote.fetchNotes(uid);
    final localNotes = await _db.getAllNotes(uid);
    final plan = _merger.plan(local: localNotes, remote: remoteNotes);

    await _db.upsertNotes(plan.toSaveLocal);
    report.downloaded += plan.toSaveLocal.length;
    for (final id in plan.toDeleteLocal) {
      await _db.deleteNote(id);
    }
    report.deletedLocal += plan.toDeleteLocal.length;

    for (final note in plan.toUpload) {
      try {
        await remote.upsertNote(note);
        await _db.updateNoteSyncStatus(note.id, SyncStatus.synced,
            expectedUpdatedAt: note.updatedAt);
        report.uploaded++;
      } on RemoteException catch (e) {
        report.failures.add(e);
        if (e.isTransient) return; // sem rede: não adianta continuar.
      }
    }

    for (final id in plan.toDeleteRemote) {
      try {
        await remote.deleteNote(uid, id);
        final current = await _db.getNote(id);
        if (current?.syncStatus == SyncStatus.pendingDelete) {
          await _db.deleteNote(id);
        }
        report.deletedRemote++;
      } on RemoteException catch (e) {
        report.failures.add(e);
        if (e.isTransient) return;
      }
    }
  }

  Future<void> _syncCategories(
      String uid, RemoteDataSource remote, SyncReport report) async {
    final remoteCategories = await remote.fetchCategories(uid);
    final localCategories = await _db.getAllCategories(uid);
    final plan =
        _merger.plan(local: localCategories, remote: remoteCategories);

    await _db.upsertCategories(plan.toSaveLocal);
    report.downloaded += plan.toSaveLocal.length;
    for (final id in plan.toDeleteLocal) {
      await _db.deleteCategory(id);
    }
    report.deletedLocal += plan.toDeleteLocal.length;

    for (final category in plan.toUpload) {
      try {
        await remote.upsertCategory(category);
        await _db.updateCategorySyncStatus(category.id, SyncStatus.synced,
            expectedUpdatedAt: category.updatedAt);
        report.uploaded++;
      } on RemoteException catch (e) {
        report.failures.add(e);
        if (e.isTransient) return;
      }
    }

    for (final id in plan.toDeleteRemote) {
      try {
        await remote.deleteCategory(uid, id);
        await _db.deleteCategory(id);
        report.deletedRemote++;
      } on RemoteException catch (e) {
        report.failures.add(e);
        if (e.isTransient) return;
      }
    }
  }
}
