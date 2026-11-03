import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:flutter/material.dart';

class CategoryBadge extends StatelessWidget {
  final Category category;
  const CategoryBadge(this.category, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = AppColors.category(category.colorIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        category.name,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
