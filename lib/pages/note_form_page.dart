import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/repositories/category_repository.dart';
import 'package:bloco_de_nota_turma_a/utils/date_format.dart';
import 'package:bloco_de_nota_turma_a/widgets/category_name_dialog.dart';
import 'package:flutter/material.dart';

/// Tela de criação e edição de notas, com seleção (ou criação) de categoria.
class NoteFormPage extends StatefulWidget {
  final String uid;
  final Note? note;

  const NoteFormPage({super.key, required this.uid, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  static const _newCategory = '__nova__';

  final titleController = TextEditingController();
  final contentController = TextEditingController();

  late final AppDependencies deps;
  List<Category> categories = [];
  String? categoryId;
  bool saving = false;
  bool _initialized = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      titleController.text = note.title;
      contentController.text = note.content;
      categoryId = note.categoryId;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    deps = AppScope.of(context);
    loadCategories();
  }

  Future<void> loadCategories() async {
    final result = await deps.categories.getAll(widget.uid);
    if (!mounted) return;
    setState(() {
      categories = result;
      // Se a categoria da nota foi excluída, a nota fica sem categoria.
      if (categoryId != null && !result.any((c) => c.id == categoryId)) {
        categoryId = null;
      }
    });
  }

  Future<void> onCategoryChanged(String? value) async {
    if (value != _newCategory) {
      setState(() => categoryId = value);
      return;
    }
    final name = await showCategoryNameDialog(context);
    if (name == null || !mounted) return;
    try {
      final created = await deps.categories.create(widget.uid, name);
      await loadCategories();
      setState(() => categoryId = created.id);
    } on CategoryException catch (e) {
      showMessage(e.message);
    }
  }

  Future<void> saveNote() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      showMessage('Escreva um título ou conteúdo para salvar.');
      return;
    }

    setState(() => saving = true);
    try {
      final note = widget.note;
      if (note == null) {
        await deps.notes.create(
          uid: widget.uid,
          title: title,
          content: content,
          categoryId: categoryId,
        );
      } else {
        await deps.notes.update(
          note,
          title: title,
          content: content,
          categoryId: categoryId,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Falha ao gravar no SQLite (ex.: armazenamento cheio).
      showMessage('Não foi possível salvar a nota: $e');
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> moveToTrash() async {
    await deps.notes.moveToTrash(widget.note!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nota movida para a lixeira.')),
    );
    Navigator.pop(context);
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar nota' : 'Nova nota',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isEditing)
            IconButton(
              tooltip: 'Mover para a lixeira',
              onPressed: saving ? null : moveToTrash,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          IconButton(
            tooltip: 'Salvar',
            onPressed: saving ? null : saveNote,
            icon: const Icon(Icons.check_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              key: ValueKey('category-${categories.length}-$categoryId'),
              // Enquanto as categorias carregam, o valor fica vazio.
              initialValue: categories.any((c) => c.id == categoryId)
                  ? categoryId
                  : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.label_outline_rounded),
                labelText: 'Categoria',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sem categoria'),
                ),
                for (final c in categories)
                  DropdownMenuItem<String?>(
                    value: c.id,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 6,
                          backgroundColor: AppColors.category(c.colorIndex).$2,
                        ),
                        const SizedBox(width: 10),
                        Text(c.name),
                      ],
                    ),
                  ),
                const DropdownMenuItem<String?>(
                  value: _newCategory,
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Nova categoria...',
                          style: TextStyle(color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
              onChanged: onCategoryChanged,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textStrong,
              ),
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
            if (note != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  'Criada em ${formatDateTime(note.createdDate)} · '
                  'Atualizada em ${formatDateTime(note.updatedDate)}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
              ),
            const Divider(color: Color(0xFFE4DFEA)),
            Expanded(
              child: TextField(
                controller: contentController,
                maxLines: null,
                expands: true,
                textCapitalization: TextCapitalization.sentences,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: AppColors.text,
                ),
                decoration: const InputDecoration(
                  hintText: 'Comece a escrever...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
