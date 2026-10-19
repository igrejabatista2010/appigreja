import 'package:flutter/material.dart';

/// Tema centralizado. A cor semente é um placeholder até a cliente enviar as
/// cores e o logo da igreja.
abstract final class AppTheme {
  static const _seed = Color(0xFF1F4E79);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: brightness,
      ),
    );
  }
}
