import 'package:firebase_auth/firebase_auth.dart';

/// Erro de autenticação com mensagem pronta para o usuário.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Encapsula o Firebase Authentication (e-mail e senha).
class AuthService {
  final FirebaseAuth _auth;

  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  /// Emite o usuário sempre que ele entra ou sai. O Firebase mantém a sessão
  /// salva no aparelho, então ao reabrir o app o usuário continua logado.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e));
    }
  }

  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_translate(e));
    }
  }

  Future<void> logout() => _auth.signOut();

  static String _translate(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'E-mail inválido.',
        'user-disabled' => 'Esta conta foi desativada.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'E-mail ou senha incorretos.',
        'email-already-in-use' => 'Já existe uma conta com este e-mail.',
        'weak-password' => 'A senha deve ter pelo menos 6 caracteres.',
        'too-many-requests' =>
          'Muitas tentativas. Aguarde um pouco e tente novamente.',
        'network-request-failed' =>
          'Sem conexão com a internet. Verifique sua rede.',
        'operation-not-allowed' =>
          'Login por e-mail/senha não está habilitado no Firebase.',
        _ => 'Não foi possível concluir a operação (${e.code}).',
      };
}
