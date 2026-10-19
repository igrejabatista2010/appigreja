import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Fuso da igreja. Toda data exibida e todo "hoje" usam este fuso,
/// **independente do fuso do aparelho**.
const churchTimeZoneName = 'America/Sao_Paulo';

/// Chamar uma vez no `main`, antes de usar qualquer função abaixo.
void initChurchTime() => tz_data.initializeTimeZones();

tz.Location get _location => tz.getLocation(churchTimeZoneName);

/// Agora, em São Paulo. [now] existe para testes.
tz.TZDateTime nowSp({DateTime? now}) => now == null
    ? tz.TZDateTime.now(_location)
    : tz.TZDateTime.from(now, _location);

/// O dia de hoje em São Paulo, à meia-noite (sem fuso). [now] existe para testes.
DateTime todaySp({DateTime? now}) {
  final value = nowSp(now: now);
  return DateTime(value.year, value.month, value.day);
}

/// Converte um instante (ex.: um `timestamptz` do banco) para São Paulo.
tz.TZDateTime toSp(DateTime value) => tz.TZDateTime.from(value, _location);
