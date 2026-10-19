// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'App da Igreja';

  @override
  String get navHome => 'Início';

  @override
  String get navSchedule => 'Agenda';

  @override
  String get navAnnouncements => 'Comunicados';

  @override
  String get navPrayer => 'Oração';

  @override
  String get navMore => 'Mais';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get loading => 'Carregando';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get emptyDefault => 'Nada por aqui ainda.';

  @override
  String get errorGeneric => 'Algo deu errado. Tente novamente.';

  @override
  String get errorNetwork =>
      'Sem conexão. Verifique sua internet e tente novamente.';

  @override
  String get errorAuth =>
      'Não foi possível entrar. Confira seus dados e tente novamente.';

  @override
  String get errorPermission => 'Você não tem permissão para fazer isso.';

  @override
  String get errorNotFound => 'Não encontramos o que você procurava.';

  @override
  String get errorValidation =>
      'Confira os dados informados e tente novamente.';
}
