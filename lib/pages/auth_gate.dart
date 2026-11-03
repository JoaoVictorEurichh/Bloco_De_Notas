import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/pages/login_page.dart';
import 'package:bloco_de_nota_turma_a/pages/notes_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Decide a tela inicial a partir do estado de autenticação.
///
/// Como o Firebase Auth mantém a sessão no aparelho, ao reabrir o app o
/// usuário vai direto para as notas, que são recuperadas do SQLite e
/// sincronizadas com o Firestore.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth!;
    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        // A key garante um NotesPage novo (e um controller novo) por usuário.
        return NotesPage(
          key: ValueKey(user.uid),
          uid: user.uid,
          email: user.email ?? '',
        );
      },
    );
  }
}
