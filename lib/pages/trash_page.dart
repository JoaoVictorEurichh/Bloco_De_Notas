import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/repositories/note_repository.dart';
import 'package:bloco_de_nota_turma_a/utils/date_format.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:flutter/material.dart';

/// Lixeira com recuperação (funcionalidade adicional).
///
/// Notas excluídas ficam aqui por até 30 dias e podem ser restauradas. Depois
/// disso, ou ao "Excluir definitivamente", são apagadas do SQLite e do
/// Firestore.
class TrashPage extends StatefulWidget {
  final String uid;
  const TrashPage({super.key, required this.uid});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  late final NoteRepository repository;
  List<Note> notes = [];
  bool loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    repository = AppScope.of(context).notes;
    load();
  }

  Future<void> load() async {
    final result =
        await repository.query(widget.uid, const NoteFilter(inTrash: true));
    if (!mounted) return;
    setState(() {
      notes = result;
      loading = false;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> restore(Note note) async {
    await repository.restore(note);
    await load();
    if (mounted) showMessage('Nota restaurada.');
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> deleteForever(Note note) async {
    final ok = await _confirm('Excluir definitivamente?',
        'A nota será apagada do aparelho e do Firebase. Esta ação não pode ser desfeita.');
    if (!ok) return;
    await repository.deletePermanently(note);
    await load();
    if (mounted) showMessage('Nota excluída definitivamente.');
  }

  Future<void> emptyTrash() async {
    final ok = await _confirm('Esvaziar lixeira?',
        'Todas as ${notes.length} nota(s) serão apagadas definitivamente.');
    if (!ok) return;
    final count = await repository.emptyTrash(widget.uid);
    await load();
    if (mounted) showMessage('$count nota(s) excluída(s).');
  }

  String remainingLabel(Note note) {
    final expires = note.deletedDate!.add(NoteRepository.trashRetention);
    final days = expires.difference(DateTime.now()).inDays;
    return 'Na lixeira desde ${formatDateTime(note.deletedDate!)} · '
        '${days <= 0 ? 'expira hoje' : 'expira em $days dia(s)'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Lixeira', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (notes.isNotEmpty)
            TextButton.icon(
              onPressed: emptyTrash,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_forever_rounded),
              label: const Text('Esvaziar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'As notas ficam na lixeira por 30 dias e depois são '
                    'excluídas definitivamente. Toque em restaurar para '
                    'recuperá-las.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: notes.isEmpty
                      ? const Center(child: Text('A lixeira está vazia.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return NoteCard(
                              key: ValueKey(note.id),
                              note: note,
                              dateLabel: remainingLabel(note),
                              onTap: () => restore(note),
                              actions: [
                                IconButton(
                                  tooltip: 'Restaurar',
                                  onPressed: () => restore(note),
                                  icon: const Icon(Icons.restore_rounded,
                                      color: AppColors.success),
                                ),
                                IconButton(
                                  tooltip: 'Excluir definitivamente',
                                  onPressed: () => deleteForever(note),
                                  icon: const Icon(
                                      Icons.delete_forever_rounded,
                                      color: AppColors.danger),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
