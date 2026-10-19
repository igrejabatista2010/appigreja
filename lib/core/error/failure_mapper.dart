import 'dart:async';
import 'dart:io';

import 'package:church_app/core/error/failures.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Converte qualquer exceção de infraestrutura em [Failure]. Os repositórios
/// usam isto para nunca deixar uma exceção chegar ao Bloc.
///
/// Só mensagens escritas por nós (erros `P0001` dos triggers e funções do banco,
/// já em pt-BR) são repassadas em `message`. Texto técnico nunca vai para a tela.
Failure mapExceptionToFailure(Object error) {
  return switch (error) {
    PostgrestException() => _fromPostgrest(error),
    AuthRetryableFetchException() => const NetworkFailure(),
    AuthException() => AuthFailure(code: error.code),
    StorageException() => _fromStatus(int.tryParse(error.statusCode ?? '')),
    FunctionException() => _fromFunction(error),
    SocketException() ||
    TimeoutException() ||
    ClientException() => const NetworkFailure(),
    _ => const ServerFailure(),
  };
}

Failure _fromPostgrest(PostgrestException error) {
  final code = error.code;
  return switch (code) {
    // raise exception dos nossos triggers/funções: texto em pt-BR, hint = código.
    'P0001' => ValidationFailure(message: error.message, code: error.hint),
    // insufficient_privilege (inclui violação de RLS)
    '42501' => const PermissionFailure(),
    // .single() sem linhas
    'PGRST116' => const NotFoundFailure(),
    // unique_violation, foreign_key_violation, not_null_violation, check_violation
    '23505' || '23503' || '23502' || '23514' => ValidationFailure(code: code),
    _ => ServerFailure(code: code),
  };
}

Failure _fromFunction(FunctionException error) {
  final details = error.details;
  if (details is Map<String, dynamic>) {
    final message = details['message'];
    if (error.status == 400 || error.status == 409 || error.status == 422) {
      return ValidationFailure(
        message: message is String ? message : null,
        code: details['code'] is String ? details['code'] as String : null,
      );
    }
  }
  return _fromStatus(error.status);
}

Failure _fromStatus(int? status) {
  return switch (status) {
    401 || 403 => const PermissionFailure(),
    404 => const NotFoundFailure(),
    400 || 409 || 422 => const ValidationFailure(),
    _ => const ServerFailure(),
  };
}
