import 'package:church_app/core/utils/church_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(initChurchTime);

  group('todaySp', () {
    test('às 22h de São Paulo ainda é o dia anterior em UTC', () {
      // 2026-10-20 01:00 UTC = 2026-10-19 22:00 em São Paulo (UTC-3).
      final today = todaySp(now: DateTime.utc(2026, 10, 20, 1));
      expect(today, DateTime(2026, 10, 19));
    });

    test('a meia-noite de São Paulo já é o novo dia', () {
      // 2026-10-20 03:00 UTC = 2026-10-20 00:00 em São Paulo.
      final today = todaySp(now: DateTime.utc(2026, 10, 20, 3));
      expect(today, DateTime(2026, 10, 20));
    });

    test(
      'um minuto antes da meia-noite de São Paulo ainda é o dia anterior',
      () {
        final today = todaySp(now: DateTime.utc(2026, 10, 20, 2, 59));
        expect(today, DateTime(2026, 10, 19));
      },
    );
  });

  group('toSp', () {
    test('converte UTC para São Paulo (UTC-3, sem horário de verão)', () {
      final value = toSp(DateTime.utc(2026, 1, 15, 12));
      expect(value.hour, 9);
      expect(value.day, 15);
      expect(value.timeZoneOffset, const Duration(hours: -3));
    });

    test('mantém o mesmo instante', () {
      final utc = DateTime.utc(2026, 7, 1, 23, 30);
      expect(toSp(utc).toUtc(), utc);
    });
  });

  test('nowSp usa o fuso de São Paulo', () {
    expect(nowSp().timeZoneOffset, const Duration(hours: -3));
  });
}
