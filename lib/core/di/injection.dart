import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final GetIt getIt = GetIt.instance;

/// Registro manual no get_it. Cada feature ganha aqui o seu bloco de registros
/// (datasource → repository → usecases → bloc).
void configureDependencies() {
  getIt.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
}
