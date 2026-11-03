// Gera as capturas de tela da interface usadas no README.
//
// Renderiza as telas reais do app (mesmo código de lib/) com um banco SQLite
// de exemplo e uma "nuvem" em memória. Não substitui as capturas do Console
// do Firebase, que comprovam o armazenamento na nuvem.
//
// Executar:
//   flutter test tool/screenshots --update-goldens
import 'dart:io';

import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/main.dart';
import 'package:bloco_de_nota_turma_a/models/note.dart';
import 'package:bloco_de_nota_turma_a/models/note_filter.dart';
import 'package:bloco_de_nota_turma_a/pages/categories_page.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/note_form_page.dart';
import 'package:bloco_de_nota_turma_a/pages/notes_page.dart';
import 'package:bloco_de_nota_turma_a/pages/trash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/fake_remote_data_source.dart';
import '../../test/helpers/test_env.dart';

const uid = 'demo-user';
const email = 'aluno@exemplo.com';

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT']!;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String f) async =>
      ByteData.sublistView(File('$dir/$f').readAsBytesSync());

  final roboto = FontLoader('Roboto')
    ..addFont(read('Roboto-Regular.ttf'))
    ..addFont(read('Roboto-Medium.ttf'))
    ..addFont(read('Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(read('MaterialIcons-Regular.otf'));
  await icons.load();
}

ThemeData theme() => buildTheme().copyWith(
      textTheme: buildTheme().textTheme.apply(fontFamily: 'Roboto'),
    );

void main() {
  late FakeRemoteDataSource cloud;
  late Installation app;
  late AppDependencies deps;
  final clock = FakeClock();

  setUpAll(() async {
    await loadFonts();
  });

  setUp(() async {
    clock.value = DateTime.now().toUtc().millisecondsSinceEpoch -
        const Duration(days: 2).inMilliseconds;
    cloud = FakeRemoteDataSource();
    app = Installation(cloud, clock);
    deps = AppDependencies(
      auth: null,
      database: app.db,
      sync: app.sync,
      notes: app.notes,
      categories: app.categories,
      connectivity: null,
      firebaseReady: true,
    );
  });

  tearDown(() => app.close());

  Future<void> seed() async {
    await app.sync.sync(uid);
    await app.categories.seedDefaultsIfEmpty(uid);
    final cats = {for (final c in await app.categories.getAll(uid)) c.name: c};
    final faculdade = await app.categories.create(uid, 'Faculdade');

    Future<Note> add(String title, String content, String? cat,
        {Duration step = const Duration(hours: 5)}) async {
      clock.advance(step);
      return app.notes.create(
          uid: uid, title: title, content: content, categoryId: cat);
    }

    await add('Lista do mercado', 'Café, leite, pão integral e frutas.',
        cats['Pessoal']!.id);
    await add('Prova de Banco de Dados',
        'Revisar normalização, índices e transações. Prova na sexta às 19h.',
        cats['Estudos']!.id);
    await add('Reunião de planejamento',
        'Pauta: cronograma da sprint, revisão do orçamento e próximos passos.',
        cats['Trabalho']!.id);
    final old = await add('Rascunho antigo', 'Ideias que não usei mais.', null);
    await add('Trabalho de Flutter',
        'Integrar SQLite com Firebase, categorias, pesquisa e lixeira.',
        faculdade.id);
    await add('Ideias para o fim de semana',
        'Trilha no parque, cinema e cozinhar algo novo.', cats['Pessoal']!.id,
        step: const Duration(hours: 2));
    await app.notes.moveToTrash(old);
    await app.sync.sync(uid);
  }

  Future<void> shoot(
    WidgetTester tester,
    Widget home,
    String name, {
    Future<void> Function()? interact,
  }) async {
    // Por padrão os testes desenham sombras como contornos sólidos.
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(412 * 2.0, 892 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      await tester.pumpWidget(AppScope(
        deps: deps,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(),
          home: home,
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.pump();
      }
      if (interact != null) await interact();
      await app.sync.idle;
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../../docs/screenshots/$name.png'));
    debugDisableShadows = true;
  }

  testWidgets('01 login', (tester) async {
    await shoot(tester, const LoginPage(), '01_login');
  });

  testWidgets('02 lista de notas', (tester) async {
    await tester.runAsync(seed);
    await shoot(tester, const NotesPage(uid: uid, email: email), '02_notas');
  });

  testWidgets('03 pesquisa', (tester) async {
    await tester.runAsync(seed);
    await shoot(tester, const NotesPage(uid: uid, email: email), '03_pesquisa',
        interact: () async {
      await tester.enterText(find.byType(TextField), 'revis');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  testWidgets('04 filtro por categoria', (tester) async {
    await tester.runAsync(seed);
    await shoot(tester, const NotesPage(uid: uid, email: email), '04_categoria',
        interact: () async {
      await tester.tap(find.widgetWithText(ChoiceChip, 'Estudos'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });
  });

  testWidgets('05 editar nota', (tester) async {
    late Note note;
    await tester.runAsync(() async {
      await seed();
      note = (await app.notes.query(uid, const NoteFilter())).firstWhere(
          (n) => n.title == 'Trabalho de Flutter');
    });
    await shoot(tester, NoteFormPage(uid: uid, note: note), '05_editar_nota');
  });

  testWidgets('06 categorias', (tester) async {
    await tester.runAsync(seed);
    await shoot(tester, const CategoriesPage(uid: uid), '06_categorias');
  });

  testWidgets('07 lixeira', (tester) async {
    await tester.runAsync(seed);
    await shoot(tester, const TrashPage(uid: uid), '07_lixeira');
  });

  testWidgets('08 sem conexão', (tester) async {
    await tester.runAsync(() async {
      await seed();
      cloud.offline = true;
      await app.notes.create(
          uid: uid,
          title: 'Nota criada offline',
          content: 'Fica salva no SQLite e é enviada quando a conexão voltar.');
    });
    await shoot(tester, const NotesPage(uid: uid, email: email), '08_offline');
  });
}
