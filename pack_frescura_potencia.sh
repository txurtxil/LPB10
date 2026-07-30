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

rep('''    final enMarcha = (status.speed ?? 0) > 1.0;
    final enchufado = status.isPluggedIn;
    final abs = kw.abs();
    final obj = (gMaxRangeKm > 0) ? gBatteryKwh / gMaxRangeKm * 100.0 : 0.0;
    final kmPorHora = obj > 0 ? (abs * 100.0 / obj) : 0.0;

    Color c;
    String note;
    String detalle;
    if (enchufado) {''',
'''    // El TCU duerme unos 13 minutos despues de cerrar el coche, y a partir de
    // ahi la nube devuelve el ULTIMO estado conocido: speed, gearStatus y
    // vehicleState envejecen todos juntos. Por eso la version anterior decia
    // "consumo bajo en marcha" con el coche aparcado en el garaje: leia una
    // velocidad de horas antes.
    //
    // Ningun campo del payload salva esto, asi que la regla es no afirmar
    // contexto si el dato no es reciente. La edad viene en el propio snapshot,
    // en signal.sts (milisegundos).
    int? edadTmp;
    final sig = status.raw['signal'];
    if (sig is Map) {
      final t = sig['sts'] ?? sig['1'];
      final ms = t is num ? t.toInt() : (t is String ? int.tryParse(t) : null);
      if (ms != null && ms > 1000000000000) {
        edadTmp = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(ms))
            .inMinutes;
      }
    }
    final int edad = edadTmp ?? -1;
    final fresco = edad >= 0 && edad < 15;

    String edadTxt() {
      if (edad < 0) return '';
      if (edad < 60) return (es ? 'hace ' : '') + edad.toString() + (es ? ' min' : ' min ago');
      final h = edad ~/ 60;
      if (h < 24) return (es ? 'hace ' : '') + h.toString() + (es ? ' h' : ' h ago');
      return (es ? 'hace ' : '') + (h ~/ 24).toString() + (es ? ' d' : ' d ago');
    }

    final enMarcha = fresco && (status.speed ?? 0) > 1.0;
    final enchufado = status.isPluggedIn;
    final abs = kw.abs();
    final obj = (gMaxRangeKm > 0) ? gBatteryKwh / gMaxRangeKm * 100.0 : 0.0;
    final kmPorHora = obj > 0 ? (abs * 100.0 / obj) : 0.0;

    Color c;
    String note;
    String detalle;
    if (!fresco) {
      final e = edadTxt();
      c = const Color(0xFF5B87AC);
      note = (es ? 'Ultimo dato conocido' : 'Last known value') +
          (e.isEmpty ? '' : ', ' + e);
      detalle = es
          ? 'El coche no esta respondiendo ahora mismo, asi que no se puede saber si estaba en marcha, parado o cargando cuando se midio este valor.'
          : 'The car is not responding right now, so there is no way to tell whether it was moving, parked or charging when this was measured.';
    } else if (enchufado) {''', 'frescura')

rep('''          Text(
            es
                ? 'Es una foto del ultimo refresco, no un promedio. El coche deja de responder unos minutos despues de cerrarlo, asi que el dato puede ser mas antiguo de lo que parece.'
                : 'This is a snapshot from the last refresh, not an average. The car stops responding a few minutes after locking, so the value may be older than it looks.',
            style: const TextStyle(color: textColor, fontSize: 11),
          ),''',
'''          Text(
            es
                ? 'Es una foto puntual, no un promedio.'
                : 'A single reading, not an average.',
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
echo -n "usa sts: "; grep -c "sig\['sts'\]" lib/main.dart
echo -n "enMarcha condicionado a fresco: "; grep -c 'final enMarcha = fresco' lib/main.dart
echo
flutter analyze 2>&1 | grep '• lib/' | grep error || echo "analyze: sin errores"
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
