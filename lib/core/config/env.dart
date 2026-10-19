/// Configuração de ambiente, injetada em tempo de compilação:
/// `flutter run --dart-define-from-file=env/dev.json`.
///
/// Só a URL e a publishable key entram no app. A secret key nunca.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static void ensureConfigured() {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      throw StateError(
        'Faltam SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY. '
        'Rode com --dart-define-from-file=env/dev.json '
        '(modelo em env/dev.example.json).',
      );
    }
  }
}
