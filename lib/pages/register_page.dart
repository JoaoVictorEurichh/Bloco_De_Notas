import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:bloco_de_nota_turma_a/core/app_dependencies.dart';
import 'package:bloco_de_nota_turma_a/services/auth_service.dart';
import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  Future<void> register() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      showMessage('Preencha todos os campos.');
      return;
    }
    if (password.length < 6) {
      showMessage('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (password != confirm) {
      showMessage('As senhas não são iguais.');
      return;
    }

    setState(() => loading = true);
    final auth = AppScope.of(context).auth!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.register(email, password);
      // O Firebase já autentica o novo usuário; o AuthGate abre as notas.
      messenger.showSnackBar(
          const SnackBar(content: Text('Conta criada com sucesso!')));
      if (mounted) Navigator.pop(context);
      return;
    } on AuthException catch (e) {
      showMessage(e.message);
    } catch (_) {
      showMessage('Não foi possível criar a conta.');
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _passwordField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      obscureText: obscurePassword,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => obscurePassword = !obscurePassword),
          icon: Icon(obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
        ),
      ),
    );
  }

  static const _labelStyle =
      TextStyle(fontWeight: FontWeight.w600, color: AppColors.text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            const Text(
              'Comece suas anotações',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Crie sua conta para começar. Suas notas ficam salvas no '
              'aparelho e na nuvem.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 35),
            const Text('E-mail', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'seu@email.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Senha', style: _labelStyle),
            const SizedBox(height: 8),
            _passwordField(passwordController, 'Mínimo de 6 caracteres'),
            const SizedBox(height: 20),
            const Text('Confirmar senha', style: _labelStyle),
            const SizedBox(height: 8),
            _passwordField(confirmPasswordController, 'Digite novamente'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Criar minha conta',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
