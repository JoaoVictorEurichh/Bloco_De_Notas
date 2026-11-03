import 'package:flutter/material.dart';

/// Paleta do app (mantém as cores do projeto base).
abstract final class AppColors {
  static const primary = Color(0xFF6C4AB6);
  static const primarySoft = Color(0xFFEDE5FA);
  static const background = Color(0xFFF7F5FC);
  static const textStrong = Color(0xFF292333);
  static const text = Color(0xFF40394A);
  static const textMuted = Color(0xFF77717F);
  static const textFaint = Color(0xFF9A94A1);
  static const danger = Color(0xFFB45F6C);
  static const success = Color(0xFF3F8F6B);
  static const warning = Color(0xFFB7791F);

  /// Cores das categorias (fundo, texto).
  static const categoryPalette = <(Color, Color)>[
    (Color(0xFFE3F0FF), Color(0xFF2F5E9E)), // azul
    (Color(0xFFFFEFD9), Color(0xFF9A5B13)), // laranja
    (Color(0xFFE2F5EA), Color(0xFF2E7650)), // verde
    (Color(0xFFFDE4EC), Color(0xFFA23B62)), // rosa
    (Color(0xFFEDE5FA), Color(0xFF5B3D9E)), // roxo
    (Color(0xFFE6F6F6), Color(0xFF26706F)), // turquesa
    (Color(0xFFF5F0D8), Color(0xFF746314)), // mostarda
  ];

  static (Color, Color) category(int index) =>
      categoryPalette[index.abs() % categoryPalette.length];
}
