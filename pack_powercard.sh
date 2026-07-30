set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/main.dart "backups_widget/main.dart.bak_$TS"
echo "Backup: backups_widget/main.dart.bak_$TS"

python3 - << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
antes = (s.count('(')-s.count(')'), s.count('{')-s.count('}'))

def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        print("ABORTA %s: %d ocurrencias" % (tag, s.count(old))); sys.exit(1)
    s = s.replace(old, new)

rep('''    // Color e interpretacion segun el flujo de potencia.
    Color c;
    String note;
    if (kw < -1) {
      c = const Color(0xFF2A6FD0); // azul: regenerando
      note = es ? 'Regenerando (recuperas bateria)' : 'Regenerating (recovering)';
    } else if (kw <= 10) {
      c = const Color(0xFF2A9D8F); // verde: eficiente
      note = es ? 'Consumo eficiente' : 'Efficient draw';
    } else if (kw <= 30) {
      c = const Color(0xFFE9A23B); // ambar
      note = es ? 'Consumo medio' : 'Medium draw';
    } else {
      c = const Color(0xFFE76F51); // rojo: alto
      note = es ? 'Consumo alto' : 'High draw';
    }
    final sign = kw < 0 ? '' : '';
    final valueStr = '${sign}${kw.abs().toStringAsFixed(1)} kW';''',
'''    // La interpretacion la decide el ESTADO del coche, no la magnitud.
    //
    // Antes se clasificaba solo por kW, asi que con el coche aparcado y 1,1 kW
    // de consumo parasito la tarjeta decia "Consumo eficiente" — que no
    // significa nada, porque no hay nada que estar conduciendo. Y con el coche
    // quieto "Regenerando" es fisicamente imposible: no hay ruedas girando.
    //
    // Ademas, el `sign` de antes devolvia cadena vacia en las DOS ramas, asi
    // que el signo nunca llegaba a pintarse.
    final enMarcha = (status.speed ?? 0) > 1.0;
    final enchufado = status.isPluggedIn;
    final abs = kw.abs();
    final obj = (gMaxRangeKm > 0) ? gBatteryKwh / gMaxRangeKm * 100.0 : 0.0;
    final kmPorHora = obj > 0 ? (abs * 100.0 / obj) : 0.0;

    Color c;
    String note;
    String detalle;
    if (enchufado) {
      c = const Color(0xFF2A6FD0);
      note = es ? 'Entrando en la bateria' : 'Going into the battery';
      detalle = es
          ? 'El coche esta enchufado.'
          : 'The car is plugged in.';
    } else if (enMarcha && kw < -0.2) {
      c = const Color(0xFF2A6FD0);
      note = es ? 'Regenerando al frenar' : 'Regenerating while braking';
      detalle = es
          ? 'El motor devuelve energia a la bateria en lugar de perderla en los frenos.'
          : 'The motor is returning energy to the battery instead of wasting it as heat.';
    } else if (enMarcha) {
      if (abs <= 10) {
        c = const Color(0xFF2A9D8F);
        note = es ? 'Consumo bajo en marcha' : 'Low draw while driving';
      } else if (abs <= 30) {
        c = const Color(0xFFE9A23B);
        note = es ? 'Consumo medio en marcha' : 'Medium draw while driving';
      } else {
        c = const Color(0xFFE76F51);
        note = es ? 'Consumo alto en marcha' : 'High draw while driving';
      }
      detalle = kmPorHora > 0
          ? (es
              ? 'A este ritmo sostenido gastarias la autonomia de unos ${kmPorHora.round()} km cada hora.'
              : 'Held steady, this would use about ${kmPorHora.round()} km of range per hour.')
          : (es ? 'Potencia que sale de la bateria ahora mismo.' : 'Power leaving the battery right now.');
    } else {
      // Coche parado y sin enchufar: clima, gestion termica, electronica.
      // Aqui NO se juzga la eficiencia, porque no se esta conduciendo.
      c = abs > 3 ? const Color(0xFFE9A23B) : const Color(0xFF2A9D8F);
      note = es ? 'Consumo con el coche parado' : 'Draw while parked';
      detalle = kmPorHora > 0
          ? (es
              ? 'Climatizacion, gestion termica de la bateria y electronica. A este ritmo perderias unos ${kmPorHora.round()} km de autonomia por hora.'
              : 'Climate, battery thermal management and electronics. At this rate you would lose about ${kmPorHora.round()} km of range per hour.')
          : (es
              ? 'Climatizacion, gestion termica de la bateria y electronica.'
              : 'Climate, battery thermal management and electronics.');
    }
    final valueStr = '${abs.toStringAsFixed(1)} kW';''', 'logica')

rep('''          Text(es ? 'Potencia de bateria (ahora)' : 'Battery power (now)',''',
'''          Text(es ? 'Potencia de bateria' : 'Battery power',''', 'titulo')

rep('''              Icon(kw < -1 ? Icons.battery_charging_full : Icons.bolt, color: c, size: 30),''',
'''              Icon((enchufado || kw < -0.2) ? Icons.battery_charging_full : Icons.bolt,
                  color: c, size: 30),''', 'icono')

rep('''          Text(
            es ? 'Valor puntual del ultimo refresco.' : 'Snapshot from last refresh.',
            style: const TextStyle(color: textColor, fontSize: 11),
          ),''',
'''          const SizedBox(height: 4),
          Text(detalle, style: const TextStyle(color: textColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            es
                ? 'Es una foto del ultimo refresco, no un promedio. El coche deja de responder unos minutos despues de cerrarlo, asi que el dato puede ser mas antiguo de lo que parece.'
                : 'This is a snapshot from the last refresh, not an average. The car stops responding a few minutes after locking, so the value may be older than it looks.',
            style: const TextStyle(color: textColor, fontSize: 11),
          ),''', 'pie')

open(p, 'w', encoding='utf-8').write(s)
d = (s.count('(')-s.count(')'), s.count('{')-s.count('}'))
print("  balance %s -> %s" % (str(antes), str(d)))
if antes != d:
    print("ABORTA: balance alterado"); sys.exit(1)
print("OK")
PYEOF

echo "--- verificaciones ---"
echo -n "sign muerto eliminado (debe 0): "; grep -c "final sign = kw < 0" lib/main.dart || true
echo -n "enMarcha: "; grep -c 'final enMarcha' lib/main.dart
echo
flutter analyze 2>&1 | grep '• lib/' | grep error || echo "analyze: sin errores"
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
