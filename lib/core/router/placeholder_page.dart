import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:church_app/core/widgets/app_empty_view.dart';
import 'package:flutter/material.dart';

typedef PlaceholderTitle = String Function(AppLocalizations l10n);

/// Página provisória de cada destino principal, substituída pela tela real
/// de cada feature nas etapas seguintes.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.titleOf, super.key});

  final PlaceholderTitle titleOf;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(titleOf(l10n))),
      body: AppEmptyView(message: l10n.comingSoon),
    );
  }
}
