import 'package:church_app/core/error/failures.dart';
import 'package:church_app/core/l10n/failure_l10n.dart';
import 'package:church_app/core/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('pt', 'BR'));
  });

  test('cada tipo tem um texto padrão em pt-BR', () {
    expect(const ServerFailure().localizedMessage(l10n), l10n.errorGeneric);
    expect(const NetworkFailure().localizedMessage(l10n), l10n.errorNetwork);
    expect(const AuthFailure().localizedMessage(l10n), l10n.errorAuth);
    expect(
      const PermissionFailure().localizedMessage(l10n),
      l10n.errorPermission,
    );
    expect(const NotFoundFailure().localizedMessage(l10n), l10n.errorNotFound);
    expect(
      const ValidationFailure().localizedMessage(l10n),
      l10n.errorValidation,
    );
  });

  test('a mensagem do servidor tem prioridade sobre o texto padrão', () {
    const failure = ValidationFailure(message: 'Texto do banco.');
    expect(failure.localizedMessage(l10n), 'Texto do banco.');
  });

  test('mensagem vazia cai no texto padrão', () {
    const failure = ValidationFailure(message: '');
    expect(failure.localizedMessage(l10n), l10n.errorValidation);
  });
}
