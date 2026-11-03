import 'package:flutter/material.dart';

/// Diálogo para digitar o nome de uma categoria. Retorna `null` se cancelado.
Future<String?> showCategoryNameDialog(
  BuildContext context, {
  String title = 'Nova categoria',
  String initialValue = '',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ex.: Faculdade, Compras, Ideias',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Salvar'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
