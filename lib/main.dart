import 'package:church_app/app.dart';
import 'package:church_app/core/config/env.dart';
import 'package:church_app/core/di/injection.dart';
import 'package:church_app/core/utils/church_time.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.ensureConfigured();

  initChurchTime();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  configureDependencies();

  runApp(const App());
}
