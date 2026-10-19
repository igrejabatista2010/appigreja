import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Envolve um widget com tema e localizações pt-BR, como no app real.
Widget testApp(Widget child) {
  return MaterialApp(
    locale: const Locale('pt', 'BR'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}
