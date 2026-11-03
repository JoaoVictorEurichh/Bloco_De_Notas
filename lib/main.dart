import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/firebase_options.dart';
import 'package:bloco_de_nota_turma_a/pages/auth_gate.dart';
import 'package:bloco_de_nota_turma_a/pages/firebase_setup_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseReady = await _initFirebase();
  final deps = AppDependencies.create(firebaseReady: firebaseReady);

  runApp(AppScope(deps: deps, child: const MyApp()));
}

/// Inicializa o Firebase sem derrubar o app caso a configuração esteja
/// ausente ou inválida; nesse caso é exibida uma tela de orientação.
Future<bool> _initFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) return false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return true;
  } catch (e) {
    debugPrint('Falha ao inicializar o Firebase: $e');
    return false;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bloco de Notas',
      theme: buildTheme(),
      home: deps.firebaseReady ? const AuthGate() : const FirebaseSetupPage(),
    );
  }
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textStrong,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
