import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/utils/text_normalizer.dart';

/// Nota do usuário.
///
/// O identificador é um UUID gerado no aparelho. Assim a mesma nota tem o
/// mesmo id no SQLite e no Firestore, o que permite criar notas offline e
/// sincronizá-las depois sem conflito de chaves.
class Note implements SyncableEntity {
  @override
  final String id;

  /// UID do usuário autenticado (Firebase Auth) dono da nota.
  final String uid;

  final String title;
  final String content;

  /// Id da categoria associada (opcional).
  final String? categoryId;

  /// Datas em milissegundos desde epoch (UTC).
  final int createdAt;
  @override
  final int updatedAt;

  /// Quando preenchido, a nota está na lixeira.
  final int? deletedAt;

  @override
  final SyncStatus syncStatus;

  const Note({
    required this.id,
    required this.uid,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.deletedAt,
    this.syncStatus = SyncStatus.pendingUpsert,
  });

  bool get isInTrash => deletedAt != null;

  DateTime get createdDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true).toLocal();
  DateTime get updatedDate =>
      DateTime.fromMillisecondsSinceEpoch(updatedAt, isUtc: true).toLocal();
  DateTime? get deletedDate => deletedAt == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(deletedAt!, isUtc: true).toLocal();

  /// Texto normalizado (minúsculo e sem acentos) usado na pesquisa.
  String get searchIndex => normalizeForSearch('$title\n$content');

  Note copyWith({
    String? title,
    String? content,
    String? categoryId,
    bool clearCategory = false,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
    SyncStatus? syncStatus,
  }) {
    return Note(
      id: id,
      uid: uid,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // ---------------------------------------------------------------------------
  // SQLite
  // ---------------------------------------------------------------------------

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'category_id': categoryId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'sync_status': syncStatus.name,
      'search_index': searchIndex,
    };
  }

  factory Note.fromDbMap(Map<String, Object?> map) {
    return Note(
      id: map['id'] as String,
      uid: map['uid'] as String,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      categoryId: map['category_id'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
      syncStatus: SyncStatus.fromName(map['sync_status'] as String?),
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore
  // ---------------------------------------------------------------------------

  /// Campos gravados no documento `users/{uid}/notes/{id}`.
  ///
  /// O estado de sincronização é local e não é enviado.
  Map<String, Object?> toFirestore() {
    return {
      'id': id,
      'uid': uid,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
    };
  }

  /// Converte um documento remoto. Notas vindas da nuvem estão sincronizadas.
  factory Note.fromFirestore(Map<String, dynamic> data) {
    return Note(
      id: data['id'] as String,
      uid: data['uid'] as String,
      title: (data['title'] as String?) ?? '',
      content: (data['content'] as String?) ?? '',
      categoryId: data['categoryId'] as String?,
      createdAt: (data['createdAt'] as num).toInt(),
      updatedAt: (data['updatedAt'] as num).toInt(),
      deletedAt: (data['deletedAt'] as num?)?.toInt(),
      syncStatus: SyncStatus.synced,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.uid == uid &&
      other.title == title &&
      other.content == content &&
      other.categoryId == categoryId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode => Object.hash(id, uid, title, content, categoryId,
      createdAt, updatedAt, deletedAt, syncStatus);

  @override
  String toString() => 'Note($id, "$title", status: ${syncStatus.name})';
}
