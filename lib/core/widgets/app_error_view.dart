import 'package:church_app/core/error/failures.dart';
import 'package:church_app/core/l10n/failure_l10n.dart';
import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// Estado de erro de toda tela com dado remoto, sempre com "Tentar novamente".
class AppErrorView extends StatelessWidget {
  const AppErrorView({required this.failure, required this.onRetry, super.key});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              failure.localizedMessage(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
