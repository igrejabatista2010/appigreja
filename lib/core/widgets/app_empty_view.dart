import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Estado vazio de toda tela com dado remoto.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    this.message,
    this.icon = Icons.inbox_outlined,
  });

  /// Quando nulo, usa o texto padrão ("Nada por aqui ainda.").
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message ?? AppLocalizations.of(context).emptyDefault,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
