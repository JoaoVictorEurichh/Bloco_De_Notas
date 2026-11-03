import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/pages/register_page.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  AuthService get authService => AppScope.of(context).auth!;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showMessage('Preencha todos os campos.');
      return;
    }
    setState(() => loading = true);
    try {
      // A navegação para as notas é feita pelo AuthGate ao detectar o login.
      await authService.login(email, password);
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (_) {
      showMessage('Não foi possível realizar o login.');
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showMessage('Digite seu e-mail para receber o link de redefinição.');
      return;
    }
    try {
      await authService.sendPasswordReset(email);
      showMessage('Enviamos um link de redefinição para $email.');
    } on AuthException catch (e) {
      showMessage(e.message);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static const _labelStyle =
      TextStyle(fontWeight: FontWeight.w600, color: AppColors.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8DDF8),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          size: 45, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 35),
                  const Text(
                    'Olá!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Entre para acessar suas notas.',
                    style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 35),
                  const Text('E-mail', style: _labelStyle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'seu@email.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Senha', style: _labelStyle),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => login(),
                    decoration: InputDecoration(
                      hintText: 'Digite sua senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : resetPassword,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child:
                          const Text('Ainda não possui uma conta? Cadastre-se'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
