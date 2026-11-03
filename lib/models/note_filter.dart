/// Critérios de ordenação da lista de notas (funcionalidade adicional).
enum NoteSortOrder {
  updatedDesc('Última atualização'),
  createdDesc('Mais recentes primeiro'),
  createdAsc('Mais antigas primeiro'),
  titleAsc('Título (A–Z)');

  const NoteSortOrder(this.label);
  final String label;

  /// Cláusula ORDER BY correspondente no SQLite.
  String get sql => switch (this) {
        NoteSortOrder.updatedDesc => 'updated_at DESC',
        NoteSortOrder.createdDesc => 'created_at DESC',
        NoteSortOrder.createdAsc => 'created_at ASC',
        NoteSortOrder.titleAsc => 'title COLLATE NOCASE ASC, updated_at DESC',
      };
}

/// Filtro aplicado na consulta de notas: pesquisa, categoria, lixeira e
/// ordenação. É imutável; o controller cria uma cópia a cada mudança.
class NoteFilter {
  final String searchTerm;

  /// `null` = todas as categorias.
  final String? categoryId;

  /// `true` lista apenas as notas da lixeira.
  final bool inTrash;

  final NoteSortOrder sortOrder;

  const NoteFilter({
    this.searchTerm = '',
    this.categoryId,
    this.inTrash = false,
    this.sortOrder = NoteSortOrder.updatedDesc,
  });

  NoteFilter copyWith({
    String? searchTerm,
    String? categoryId,
    bool clearCategory = false,
    bool? inTrash,
    NoteSortOrder? sortOrder,
  }) {
    return NoteFilter(
      searchTerm: searchTerm ?? this.searchTerm,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      inTrash: inTrash ?? this.inTrash,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
