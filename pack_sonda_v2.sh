set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/leapmotor_engine.dart "backups_widget/leapmotor_engine.dart.bak_$TS"
echo "Backup: backups_widget/leapmotor_engine.dart.bak_$TS"

python3 - << 'PYEOF'
import sys
p = 'lib/leapmotor_engine.dart'
s = open(p, encoding='utf-8').read()
antes = (s.count('(')-s.count(')'), s.count('{')-s.count('}'))

ini = s.find('  Future<String> probeChargeHistoryRaw(')
if ini < 0:
    print("ABORTA: no encuentro la sonda"); sys.exit(1)
marca = "    return 'HTTP ${response.statusCode}  ($startTime .. $endTime)\\n${response.body}';\n  });"
fin = s.find(marca, ini)
if fin < 0:
    print("ABORTA: no encuentro el final de la sonda"); sys.exit(1)
fin += len(marca)

nuevo = r'''  /// Una sola llamada al endpoint de cargas, con los parametros dados.
  Future<String> _probeCargas(String vin, String startTime, String endTime,
      String timeZone, String etiqueta) async {
    try {
      final headers = _signedHeaders(vin: vin, bodyParams: {
        'timeZone': timeZone,
        'startTime': startTime,
        'endTime': endTime,
        'pageNum': '1',
        'pageSize': '20',
      })..addAll(_authHeaders());
      headers['Content-Type'] = 'application/json';
      final body = json.encode({
        'vin': vin,
        'timeZone': timeZone,
        'startTime': startTime,
        'endTime': endTime,
        'pageNum': 1,
        'pageSize': 20,
      });
      final r = await _accountClient!.post(
        Uri.parse('$kBaseUrl/carownerservice/charge/daily/detail/page'),
        headers: headers,
        body: body,
      );
      var cuerpo = r.body;
      if (cuerpo.length > 700) cuerpo = cuerpo.substring(0, 700) + '...';
      return '### $etiqueta\n$startTime .. $endTime  tz=$timeZone\nHTTP ${r.statusCode}  $cuerpo\n';
    } catch (e) {
      return '### $etiqueta\nEXCEPCION: $e\n';
    }
  }

  /// SONDA v2: barrido de variantes.
  ///
  /// La v1 devolvio HTTP 200 con code 0 ("Request successful") pero list=null y
  /// total=0, pese a haber una carga real dentro de la ventana. Eso descarta
  /// que falle la firma (daria codigo != 0) y deja tres sospechosos: el formato
  /// de fecha, la zona horaria, o que el B10 sencillamente no suba sus sesiones
  /// a la nube. Se prueban todos de una vez para no gastar una publicacion por
  /// hipotesis.
  Future<String> probeChargeHistoryRaw(String vin, {int days = 7}) => withTokenRetry(() async {
    if (_accountClient == null) throw Exception('Not logged in');
    String d(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    String dSlash(DateTime x) =>
        '${x.year.toString().padLeft(4, '0')}/${x.month.toString().padLeft(2, '0')}/${x.day.toString().padLeft(2, '0')}';

    final hoy = DateTime.now();
    final d7 = hoy.subtract(const Duration(days: 7));
    final d30 = hoy.subtract(const Duration(days: 30));
    final d90 = hoy.subtract(const Duration(days: 90));

    final buf = StringBuffer();
    buf.writeln('SONDA v2 - barrido de variantes');
    buf.writeln('Hora local: ${hoy.toIso8601String()}');
    buf.writeln('');

    buf.write(await _probeCargas(vin, d(d7), d(hoy), 'GMT+00:00', '1. control, 7 dias, UTC'));
    buf.write(await _probeCargas(vin, d(d30), d(hoy), 'GMT+02:00', '2. 30 dias, GMT+02'));
    buf.write(await _probeCargas(vin, d(d90), d(hoy), 'GMT+02:00', '3. 90 dias, GMT+02'));
    buf.write(await _probeCargas(vin, '${d(d30)} 00:00:00', '${d(hoy)} 23:59:59',
        'GMT+02:00', '4. con hora'));
    buf.write(await _probeCargas(vin, dSlash(d30), dSlash(hoy), 'GMT+02:00', '5. barras'));
    buf.write(await _probeCargas(
        vin,
        d30.millisecondsSinceEpoch.toString(),
        hoy.millisecondsSinceEpoch.toString(),
        'GMT+02:00',
        '6. epoch en milisegundos'));
    buf.write(await _probeCargas(vin, d(d30), d(hoy), 'Europe/Madrid', '7. zona con nombre'));

    return buf.toString();
  });'''

s = s[:ini] + nuevo + s[fin:]
open(p, 'w', encoding='utf-8').write(s)
d2 = (s.count('(')-s.count(')'), s.count('{')-s.count('}'))
print("  balance %s -> %s" % (str(antes), str(d2)))
if antes != d2:
    print("ABORTA: balance alterado"); sys.exit(1)
print("OK")
PYEOF

echo "--- verificaciones ---"
echo -n "variantes: "; grep -c '_probeCargas(vin' lib/leapmotor_engine.dart
flutter analyze 2>&1 | grep '• lib/' | grep error || echo "analyze: sin errores"
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
