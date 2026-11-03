import 'package:bloco_de_nota_turma_a/models/sync_status.dart';

/// Categoria usada para organizar as notas (ex.: Estudos, Trabalho, Pessoal).
class Category implements SyncableEntity {
  @override
  final String id;
  final String uid;
  final String name;

  /// Índice de uma cor da paleta em `AppColors.categoryPalette`.
  final int colorIndex;

  @override
  final int updatedAt;
  @override
  final SyncStatus syncStatus;

  const Category({
    required this.id,
    required this.uid,
    required this.name,
    required this.updatedAt,
    this.colorIndex = 0,
    this.syncStatus = SyncStatus.pendingUpsert,
  });

  Category copyWith({
    String? name,
    int? colorIndex,
    int? updatedAt,
    SyncStatus? syncStatus,
  }) {
    return Category(
      id: id,
      uid: uid,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, Object?> toDbMap() => {
        'id': id,
        'uid': uid,
        'name': name,
        'color_index': colorIndex,
        'updated_at': updatedAt,
        'sync_status': syncStatus.name,
      };

  factory Category.fromDbMap(Map<String, Object?> map) => Category(
        id: map['id'] as String,
        uid: map['uid'] as String,
        name: map['name'] as String,
        colorIndex: (map['color_index'] as int?) ?? 0,
        updatedAt: map['updated_at'] as int,
        syncStatus: SyncStatus.fromName(map['sync_status'] as String?),
      );

  Map<String, Object?> toFirestore() => {
        'id': id,
        'uid': uid,
        'name': name,
        'colorIndex': colorIndex,
        'updatedAt': updatedAt,
      };

  factory Category.fromFirestore(Map<String, dynamic> data) => Category(
        id: data['id'] as String,
        uid: data['uid'] as String,
        name: data['name'] as String,
        colorIndex: (data['colorIndex'] as num?)?.toInt() ?? 0,
        updatedAt: (data['updatedAt'] as num).toInt(),
        syncStatus: SyncStatus.synced,
      );

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.uid == uid &&
      other.name == name &&
      other.colorIndex == colorIndex &&
      other.updatedAt == updatedAt &&
      other.syncStatus == syncStatus;

  @override
  int get hashCode =>
      Object.hash(id, uid, name, colorIndex, updatedAt, syncStatus);
}
