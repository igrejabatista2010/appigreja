import 'dart:async';
import 'dart:io';

import 'package:church_app/core/error/failure_mapper.dart';
import 'package:church_app/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Postgrest', () {
    test('P0001 (raise exception nosso) repassa a mensagem e o hint', () {
      final failure = mapExceptionToFailure(
        const PostgrestException(
          message: 'É preciso manter pelo menos um administrador.',
          code: 'P0001',
          hint: 'last_admin',
        ),
      );
      expect(
        failure,
        const ValidationFailure(
          message: 'É preciso manter pelo menos um administrador.',
          code: 'last_admin',
        ),
      );
    });

    test('42501 (RLS / privilégio) vira PermissionFailure', () {
      final failure = mapExceptionToFailure(
        const PostgrestException(message: 'new row violates', code: '42501'),
      );
      expect(failure, const PermissionFailure());
    });

    test('PGRST116 (single sem linha) vira NotFoundFailure', () {
      final failure = mapExceptionToFailure(
        const PostgrestException(message: 'no rows', code: 'PGRST116'),
      );
      expect(failure, const NotFoundFailure());
    });

    test('23505 (unique) vira ValidationFailure sem texto técnico', () {
      final failure = mapExceptionToFailure(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      );
      expect(failure, const ValidationFailure(code: '23505'));
      expect(failure.message, isNull);
    });

    test('código desconhecido vira ServerFailure sem expor a mensagem', () {
      final failure = mapExceptionToFailure(
        const PostgrestException(message: 'boom interno', code: 'XX000'),
      );
      expect(failure, const ServerFailure(code: 'XX000'));
      expect(failure.message, isNull);
    });
  });

  group('Auth', () {
    test('AuthException guarda só o código', () {
      final failure = mapExceptionToFailure(
        const AuthException(
          'Email not confirmed',
          statusCode: '400',
          code: 'email_not_confirmed',
        ),
      );
      expect(failure, const AuthFailure(code: 'email_not_confirmed'));
      expect(failure.message, isNull);
    });

    test('AuthRetryableFetchException (sem rede) vira NetworkFailure', () {
      final failure = mapExceptionToFailure(
        AuthRetryableFetchException(message: 'sem rede'),
      );
      expect(failure, const NetworkFailure());
    });
  });

  group('Rede', () {
    test('SocketException, TimeoutException e ClientException', () {
      expect(
        mapExceptionToFailure(const SocketException('offline')),
        const NetworkFailure(),
      );
      expect(
        mapExceptionToFailure(TimeoutException('lento')),
        const NetworkFailure(),
      );
      expect(
        mapExceptionToFailure(ClientException('Failed host lookup')),
        const NetworkFailure(),
      );
    });
  });

  group('Storage', () {
    test('404 → NotFound, 403 → Permission, 500 → Server', () {
      expect(
        mapExceptionToFailure(const StorageException('x', statusCode: '404')),
        const NotFoundFailure(),
      );
      expect(
        mapExceptionToFailure(const StorageException('x', statusCode: '403')),
        const PermissionFailure(),
      );
      expect(
        mapExceptionToFailure(const StorageException('x', statusCode: '500')),
        const ServerFailure(),
      );
    });
  });

  group('Edge Functions', () {
    test('400 com message e code repassa os dois', () {
      final failure = mapExceptionToFailure(
        FunctionException(
          status: 400,
          details: {
            'message': 'Você é o único administrador.',
            'code': 'last_admin',
          },
        ),
      );
      expect(
        failure,
        const ValidationFailure(
          message: 'Você é o único administrador.',
          code: 'last_admin',
        ),
      );
    });

    test('401 vira PermissionFailure e 500 vira ServerFailure', () {
      expect(
        mapExceptionToFailure(FunctionException(status: 401)),
        const PermissionFailure(),
      );
      expect(
        mapExceptionToFailure(FunctionException(status: 500)),
        const ServerFailure(),
      );
    });
  });

  test('exceção desconhecida vira ServerFailure', () {
    expect(mapExceptionToFailure(StateError('x')), const ServerFailure());
  });
}
