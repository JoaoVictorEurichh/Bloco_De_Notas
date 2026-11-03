import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/utils/date_format.dart';
import 'package:bloco_de_nota_turma_a/widgets/category_badge.dart';
import 'package:bloco_de_nota_turma_a/widgets/highlighted_text.dart';
import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final Category? category;
  final String searchTerm;
  final VoidCallback onTap;

  /// Ações exibidas à direita (lixeira, restaurar, excluir...).
  final List<Widget> actions;

  /// Texto da data exibida (ex.: "Atualizada em ...").
  final String? dateLabel;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.category,
    this.searchTerm = '',
    this.actions = const [],
    this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pending = note.syncStatus != SyncStatus.synced;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.notes_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(
                      note.title.isEmpty ? 'Sem título' : note.title,
                      query: searchTerm,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (note.content.isNotEmpty)
                      HighlightedText(
                        note.content,
                        query: searchTerm,
                        maxLines: 2,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (category != null) CategoryBadge(category!),
                        Text(
                          dateLabel ?? formatDateTime(note.updatedDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textFaint,
                          ),
                        ),
                        Tooltip(
                          message: pending
                              ? 'Aguardando envio ao Firebase'
                              : 'Sincronizada com o Firebase',
                          child: Icon(
                            pending
                                ? Icons.cloud_upload_outlined
                                : Icons.cloud_done_outlined,
                            size: 15,
                            color: pending
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
