import 'package:bloco_de_nota_turma_a/models/category.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/sync_status.dart';
import 'package:bloco_de_nota_turma_a/pages/firebase_setup_page.dart';
import 'package:bloco_de_nota_turma_a/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NoteCard mostra título, categoria e destaca a pesquisa',
      (tester) async {
    const note = Note(
      id: 'n1',
      uid: 'u1',
      title: 'Reunião de equipe',
      content: 'Discutir orçamento',
      createdAt: 0,
      updatedAt: 0,
      syncStatus: SyncStatus.pendingUpsert,
    );
    const category =
        Category(id: 'c1', uid: 'u1', name: 'Trabalho', updatedAt: 0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteCard(
          note: note,
          category: category,
          searchTerm: 'reuniao',
          onTap: () {},
        ),
      ),
    ));

    expect(find.text('Trabalho'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

    final title = tester.widget<Text>(find.byWidgetPredicate(
        (w) => w is Text && w.textSpan?.toPlainText() == 'Reunião de equipe'));
    final highlighted = <String>[];
    title.textSpan!.visitChildren((span) {
      if (span is TextSpan && span.style?.backgroundColor != null) {
        highlighted.add(span.text!);
      }
      return true;
    });
    expect(highlighted, ['Reunião']);
  });

  testWidgets('tela de configuração aparece sem Firebase', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FirebaseSetupPage()));
    expect(find.text('Firebase não configurado'), findsOneWidget);
  });
}
