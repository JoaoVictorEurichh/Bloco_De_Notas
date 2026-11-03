import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/utils/text_normalizer.dart';
import 'package:flutter/material.dart';

/// Texto com os trechos que correspondem à pesquisa destacados.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  const HighlightedText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final term = normalizeForSearch(query.trim());
    final normalized = normalizeForSearch(text);
    // A normalização troca caractere por caractere; se o tamanho mudar
    // (caso raro de Unicode), exibe sem destaque para não errar posições.
    if (term.isEmpty || normalized.length != text.length) {
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = normalized.indexOf(term, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(TextSpan(
        text: text.substring(index, index + term.length),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFE9A8),
          color: AppColors.textStrong,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = index + term.length;
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
