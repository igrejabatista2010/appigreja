import 'package:church_app/core/error/failures.dart';
import 'package:church_app/core/l10n/generated/app_localizations.dart';

extension FailureL10n on Failure {
  /// A mensagem do servidor (pt-BR, escrita por nós), se houver; senão o texto
  /// padrão do tipo de erro.
  String localizedMessage(AppLocalizations l10n) {
    final custom = message;
    if (custom != null && custom.isNotEmpty) return custom;
    return switch (this) {
      ServerFailure() => l10n.errorGeneric,
      NetworkFailure() => l10n.errorNetwork,
      AuthFailure() => l10n.errorAuth,
      PermissionFailure() => l10n.errorPermission,
      NotFoundFailure() => l10n.errorNotFound,
      ValidationFailure() => l10n.errorValidation,
    };
  }
}
