import 'dart:async';

import 'package:bloco_de_nota_turma_a/controllers/notes_controller.dart';
import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/pages/categories_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/pages/trash_page.dart';
import 'package:bloco_de_nota_turma_a/utils/date_format.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:bloco_de_nota_turma_a/widgets/sync_status_banner.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  final String uid;
  final String email;
  const NotesPage({super.key, required this.uid, required this.email});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final NotesController controller;
  late final AppDependencies deps;
  final searchController = TextEditingController();
  Timer? _debounce;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    deps = AppScope.of(context);
    controller = NotesController(
      uid: widget.uid,
      notesRepository: deps.notes,
      categoryRepository: deps.categories,
      syncService: deps.sync,
      connectivity: deps.connectivity,
    );
    controller.init();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    controller.dispose();
    super.dispose();
  }

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      controller.setSearchTerm(value);
    });
  }

  Future<void> openNote([Note? note]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteFormPage(uid: widget.uid, note: note),
      ),
    );
    await controller.reload();
  }

  Future<void> moveToTrash(Note note) async {
    await controller.moveToTrash(note);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Nota movida para a lixeira.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            final current = await deps.notes.getById(note.id);
            if (current != null) await controller.restore(current);
          },
        ),
      ));
  }

  Future<void> syncNow() async {
    final report = await controller.syncNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(report.ok
            ? 'Sincronizado: ${report.uploaded} enviada(s), '
                '${report.downloaded} recebida(s).'
            : report.failures.first.message),
      ));
  }

  Future<void> logout() async {
    final pending = deps.sync.state.pendingCount;
    if (pending > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair da conta?'),
          content: Text(
            'Há $pending alteração(ões) ainda não enviadas ao Firebase. '
            'Elas continuam salvas neste aparelho e serão enviadas quando '
            'você entrar novamente.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sair')),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await deps.auth!.logout(); // o AuthGate volta para o login.
  }

  Future<void> onMenu(String value) async {
    switch (value) {
      case 'categories':
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => CategoriesPage(uid: widget.uid)),
        );
      case 'trash':
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TrashPage(uid: widget.uid)),
        );
      case 'logout':
        await logout();
        return;
    }
    await controller.reload();
  }

  Future<void> chooseSortOrder() async {
    final selected = await showModalBottomSheet<NoteSortOrder>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Ordenar notas por',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final order in NoteSortOrder.values)
              ListTile(
                title: Text(order.label),
                trailing: controller.filter.sortOrder == order
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, order),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await controller.setSortOrder(selected);
  }

  String dateLabelFor(Note note) {
    return switch (controller.filter.sortOrder) {
      NoteSortOrder.createdAsc ||
      NoteSortOrder.createdDesc =>
        'Criada em ${formatDateTime(note.createdDate)}',
      _ => 'Atualizada em ${formatDateTime(note.updatedDate)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas notas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Ordenar',
            onPressed: chooseSortOrder,
            icon: const Icon(Icons.sort_rounded),
          ),
          ListenableBuilder(
            listenable: deps.sync,
            builder: (context, _) => IconButton(
              tooltip: 'Sincronizar agora',
              onPressed: deps.sync.state.isSyncing ? null : syncNow,
              icon: const Icon(Icons.sync_rounded),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'categories',
                child: ListTile(
                  leading: Icon(Icons.label_outline_rounded),
                  title: Text('Categorias'),
                ),
              ),
              PopupMenuItem(
                value: 'trash',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Lixeira'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Sair'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNote(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova nota',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.email,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: deps.sync,
                builder: (context, _) => SyncStatusBanner(
                  state: deps.sync.state,
                  onRetry: syncNow,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Pesquisar por título ou conteúdo',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar pesquisa',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            searchController.clear();
                            controller.setSearchTerm('');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _CategoryFilter(controller: controller),
              const SizedBox(height: 8),
              if (controller.isSearching && !controller.loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${controller.notes.length} resultado(s) encontrado(s)',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.notes.isEmpty) {
      return RefreshIndicator(
        onRefresh: syncNow,
        child: ListView(
          children: [
            const SizedBox(height: 60),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                    color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(
                  controller.isSearching
                      ? Icons.search_off_rounded
                      : Icons.sticky_note_2_rounded,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 25),
            Center(
              child: Text(
                controller.isSearching
                    ? 'Nenhuma nota encontrada'
                    : 'Nenhuma nota ainda',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textStrong),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                controller.isSearching
                    ? 'Tente outro termo ou categoria.'
                    : 'Crie sua primeira nota.',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: syncNow,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: controller.notes.length,
        itemBuilder: (context, index) {
          final note = controller.notes[index];
          return NoteCard(
            key: ValueKey(note.id),
            note: note,
            category: controller.categoryOf(note),
            searchTerm: controller.filter.searchTerm,
            dateLabel: dateLabelFor(note),
            onTap: () => openNote(note),
            actions: [
              IconButton(
                tooltip: 'Mover para a lixeira',
                onPressed: () => moveToTrash(note),
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final NotesController controller;
  const _CategoryFilter({required this.controller});

  @override
  Widget build(BuildContext context) {
    final selected = controller.filter.categoryId;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: selected == null,
              onSelected: (_) => controller.setCategory(null),
            ),
          ),
          for (final category in controller.categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.name),
                selected: selected == category.id,
                showCheckmark: false,
                selectedColor: AppColors.category(category.colorIndex).$1,
                avatar: CircleAvatar(
                  backgroundColor: AppColors.category(category.colorIndex).$2,
                  radius: 5,
                ),
                onSelected: (isSelected) =>
                    controller.setCategory(isSelected ? category.id : null),
              ),
            ),
        ],
      ),
    );
  }
}
