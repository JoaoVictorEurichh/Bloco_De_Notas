import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/services/sync_service.dart';
import 'package:bloco_de_nota_turma_a/utils/date_format.dart';
import 'package:flutter/material.dart';

/// Mostra o estado da sincronização com o Firebase e permite tentar de novo.
class SyncStatusBanner extends StatelessWidget {
  final SyncState state;
  final VoidCallback onRetry;

  const SyncStatusBanner({
    super.key,
    required this.state,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = switch (state.phase) {
      SyncPhase.syncing => (
          Icons.sync_rounded,
          AppColors.primary,
          'Sincronizando com o Firebase...',
        ),
      SyncPhase.error => (
          Icons.cloud_off_rounded,
          AppColors.danger,
          '${state.error?.message ?? 'Falha na sincronização.'}'
              '${state.pendingCount > 0 ? ' (${state.pendingCount} pendente(s))' : ''}',
        ),
      SyncPhase.success when state.pendingCount > 0 => (
          Icons.cloud_upload_outlined,
          AppColors.warning,
          '${state.pendingCount} alteração(ões) aguardando envio.',
        ),
      SyncPhase.success => (
          Icons.cloud_done_rounded,
          AppColors.success,
          'Sincronizado às ${formatTime(state.lastSyncedAt!)}',
        ),
      SyncPhase.idle => (
          Icons.cloud_queue_rounded,
          AppColors.textMuted,
          'Aguardando sincronização...',
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (state.isSyncing)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.5, color: color)),
          ),
          if (state.phase == SyncPhase.error)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Tentar de novo'),
            ),
        ],
      ),
    );
  }
}
