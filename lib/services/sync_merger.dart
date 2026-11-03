import 'package:bloco_de_nota_turma_a/models/sync_status.dart';

/// Resultado da comparação entre os registros locais e remotos de uma coleção.
class SyncPlan<T extends SyncableEntity> {
  /// Registros locais que devem ser enviados ao Firestore.
  final List<T> toUpload = [];

  /// Ids que devem ser apagados no Firestore.
  final List<String> toDeleteRemote = [];

  /// Registros remotos que devem ser gravados no SQLite.
  final List<T> toSaveLocal = [];

  /// Ids que devem ser removidos do SQLite (foram apagados em outro aparelho).
  final List<String> toDeleteLocal = [];

  bool get isEmpty =>
      toUpload.isEmpty &&
      toDeleteRemote.isEmpty &&
      toSaveLocal.isEmpty &&
      toDeleteLocal.isEmpty;
}

/// Estratégia de sincronização (padrão **Strategy**, função pura).
///
/// Regras, para cada id:
///
/// | Local                   | Remoto             | Ação                                  |
/// |-------------------------|--------------------|---------------------------------------|
/// | não existe              | existe             | baixar para o SQLite                  |
/// | `synced`                | existe e diferente | baixar (alteração de outro aparelho)  |
/// | `synced`                | não existe         | apagar local (excluída em outro lugar)|
/// | `pendingUpsert`         | não existe         | enviar                                |
/// | `pendingUpsert`         | existe             | *last write wins* por `updatedAt`     |
/// | `pendingDelete`         | qualquer           | apagar no Firestore                   |
///
/// Por ser uma função pura (sem I/O), é coberta por testes unitários.
class SyncMerger {
  const SyncMerger();

  SyncPlan<T> plan<T extends SyncableEntity>({
    required List<T> local,
    required List<T> remote,
  }) {
    final plan = SyncPlan<T>();
    final remoteById = {for (final r in remote) r.id: r};
    final localIds = <String>{};

    for (final l in local) {
      localIds.add(l.id);
      final r = remoteById[l.id];

      switch (l.syncStatus) {
        case SyncStatus.pendingDelete:
          plan.toDeleteRemote.add(l.id);
        case SyncStatus.pendingUpsert:
          if (r == null || l.updatedAt >= r.updatedAt) {
            plan.toUpload.add(l);
          } else {
            // A versão da nuvem é mais nova: ela vence o conflito.
            plan.toSaveLocal.add(r);
          }
        case SyncStatus.synced:
          if (r == null) {
            plan.toDeleteLocal.add(l.id);
          } else if (r != l) {
            plan.toSaveLocal.add(r);
          }
      }
    }

    for (final r in remote) {
      if (!localIds.contains(r.id)) plan.toSaveLocal.add(r);
    }
    return plan;
  }
}
