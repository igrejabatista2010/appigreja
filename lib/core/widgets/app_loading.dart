import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: AppLocalizations.of(context).loading,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
