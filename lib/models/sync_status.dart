/// Estado de sincronização de um registro local em relação ao Firestore.
///
/// - [synced]: o registro local é idêntico ao que está na nuvem.
/// - [pendingUpsert]: o registro foi criado/alterado localmente e ainda
///   precisa ser enviado para o Firestore.
/// - [pendingDelete]: o registro foi excluído definitivamente no aparelho e a
///   exclusão ainda precisa ser replicada no Firestore. Enquanto isso ele fica
///   oculto na interface.
enum SyncStatus {
  synced,
  pendingUpsert,
  pendingDelete;

  static SyncStatus fromName(String? name) {
    return SyncStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => SyncStatus.pendingUpsert,
    );
  }
}

/// Contrato comum às entidades sincronizadas (notas e categorias).
///
/// O [SyncMerger] trabalha apenas com esta interface, o que permite reutilizar
/// a mesma estratégia de sincronização para qualquer coleção.
abstract interface class SyncableEntity {
  String get id;

  /// Momento da última alteração (milissegundos desde epoch, UTC).
  int get updatedAt;

  SyncStatus get syncStatus;
}
