import 'package:bloco_de_nota_turma_a/core/app_colors.dart';
import 'package:flutter/material.dart';

/// Exibida quando o app foi compilado sem a configuração do Firebase.
class FirebaseSetupPage extends StatelessWidget {
  const FirebaseSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.danger),
              SizedBox(height: 20),
              Text(
                'Firebase não configurado',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textStrong,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'O aplicativo precisa das credenciais do seu projeto Firebase '
                'para autenticar usuários e sincronizar as notas.\n\n'
                '1. Copie firebase.env.example.json para firebase.env.json\n'
                '2. Preencha com os dados do seu projeto (Console do Firebase '
                '> Configurações do projeto)\n'
                '3. Execute:\n'
                '   flutter run --dart-define-from-file=firebase.env.json\n\n'
                'O passo a passo completo está no README.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
