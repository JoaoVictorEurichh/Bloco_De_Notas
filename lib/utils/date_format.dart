String _two(int v) => v.toString().padLeft(2, '0');

/// Formata a data no padrão brasileiro: `dd/MM/yyyy HH:mm`.
String formatDateTime(DateTime date) {
  return '${_two(date.day)}/${_two(date.month)}/${date.year} '
      '${_two(date.hour)}:${_two(date.minute)}';
}

/// Formata somente o horário: `HH:mm`.
String formatTime(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';
