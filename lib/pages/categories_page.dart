import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/repositories/category_repository.dart';
import 'package:bloco_de_nota_turma_a/widgets/category_name_dialog.dart';
import 'package:flutter/material.dart';

/// Gerenciamento das categorias do usuário: criar, renomear e excluir.
class CategoriesPage extends StatefulWidget {
  final String uid;
  const CategoriesPage({super.key, required this.uid});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late final CategoryRepository repository;
  List<Category> categories = [];
  bool loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    repository = AppScope.of(context).categories;
    load();
  }

  Future<void> load() async {
    final result = await repository.getAll(widget.uid);
    if (!mounted) return;
    setState(() {
      categories = result;
      loading = false;
    });
  }

  Future<void> create() async {
    final name = await showCategoryNameDialog(context);
    if (name == null) return;
    await _run(() => repository.create(widget.uid, name));
  }

  Future<void> rename(Category category) async {
    final name = await showCategoryNameDialog(
      context,
      title: 'Renomear categoria',
      initialValue: category.name,
    );
    if (name == null) return;
    await _run(() => repository.rename(category, name));
  }

  Future<void> delete(Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${category.name}"?'),
        content: const Text(
            'As notas desta categoria não serão apagadas; elas ficarão '
            'sem categoria.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (confirm == true) await _run(() => repository.delete(category));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await load();
    } on CategoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova categoria'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : categories.isEmpty
              ? const Center(child: Text('Nenhuma categoria cadastrada.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final (bg, fg) = AppColors.category(category.colorIndex);
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        leading: CircleAvatar(
                          backgroundColor: bg,
                          child: Icon(Icons.label_rounded, color: fg),
                        ),
                        title: Text(category.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Renomear',
                              onPressed: () => rename(category),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Excluir',
                              onPressed: () => delete(category),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.danger),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
