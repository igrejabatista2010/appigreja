import 'package:equatable/equatable.dart';

/// Erro de negócio devolvido pelos repositórios (`Either<Failure, T>`).
/// Dart puro: pode ser usado na camada `domain`.
sealed class Failure extends Equatable {
  const Failure({this.message, this.code});

  /// Texto já em pt-BR e seguro para mostrar ao usuário (ex.: mensagem de um
  /// `raise exception` do banco). Quando nulo, a UI usa o texto padrão do tipo.
  final String? message;

  /// Identificador técnico para a UI decidir o fluxo (ex.: `email_not_confirmed`,
  /// `last_admin`).
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

final class ServerFailure extends Failure {
  const ServerFailure({super.message, super.code});
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.code});
}

final class AuthFailure extends Failure {
  const AuthFailure({super.message, super.code});
}

final class PermissionFailure extends Failure {
  const PermissionFailure({super.message, super.code});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message, super.code});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({super.message, super.code});
}
