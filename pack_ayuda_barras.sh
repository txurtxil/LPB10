#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/main.dart backups_widget/main.dart.bak_$TS
echo "[i] Backup en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

# 1. Estado para desplegar la ayuda
old_state = "  List<Map<String, dynamic>> _history = [];"
if s.count(old_state) != 1:
    sys.exit("ABORT: ancla _history x%d" % s.count(old_state))
s = s.replace(old_state, old_state + "\n  bool _showHelp = false;", 1)

# 2. Insertar la ayuda justo despues del bloque de barras.
#    Se localiza por el texto unico de "historial vacio" y se busca el cierre
#    de la lista de children que viene despues.
marker = "'Historial vacio (se rellena con el uso)'"
if s.count(marker) != 1:
    sys.exit("ABORT: marcador historial vacio x%d" % s.count(marker))
idx = s.index(marker)
close = s.index("\n        ],", idx)

help_es = (
    "Barras: cada barra es una lectura del nivel de bateria guardada por la app. "
    "La mas antigua a la izquierda, la mas reciente a la derecha. Bajan cuando "
    "conduces y suben cuando cargas; sirven para ver la evolucion de un vistazo. "
    "No son consumo: para eso esta la tarjeta Consumo y autonomia real.\\n\\n"
    "Porcentaje grande: carga actual con un decimal, mas preciso que el numero "
    "redondeado del coche.\\n\\n"
    "Km: autonomia que reporta el coche en esta lectura.\\n\\n"
    "Candado: si el coche estaba cerrado o abierto en la ultima lectura.\\n\\n"
    "Hace X: cuando se tomaron estos datos. La app consulta cada 90 s con la "
    "app abierta y cada 15 min en segundo plano (limite de Android), asi que "
    "no es informacion en vivo."
)
help_en = (
    "Bars: each bar is a battery level reading stored by the app. Oldest on the "
    "left, most recent on the right. They go down as you drive and up as you "
    "charge, so you can see the trend at a glance. They are not consumption: "
    "see the Real consumption and range card for that.\\n\\n"
    "Big percentage: current charge with one decimal, more precise than the "
    "rounded figure shown by the car.\\n\\n"
    "Km: range reported by the car in this reading.\\n\\n"
    "Padlock: whether the car was locked or unlocked at the last reading.\\n\\n"
    "X ago: when this data was read. The app polls every 90 s while open and "
    "every 15 min in the background (Android limit), so it is not live data."
)

block = '''
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showHelp = !_showHelp),
            child: Row(
              children: [
                Icon(_showHelp ? Icons.expand_less : Icons.help_outline,
                    size: 16, color: textColor),
                const SizedBox(width: 4),
                Text(
                  Localizations.localeOf(context).languageCode == 'es'
                      ? 'Que significa esto?'
                      : 'What does this mean?',
                  style: const TextStyle(
                      color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_showHelp)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? '%s'
                    : '%s',
                style: const TextStyle(color: textColor, fontSize: 11, height: 1.35),
              ),
            ),''' % (help_es, help_en)

s = s[:close] + block + s[close:]
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] main.dart: ayuda desplegable en la tarjeta de bateria")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance preservado')
"
cp /tmp/pruebatest/main.dart lib/main.dart

echo "[i] Verificacion:"
echo -n "  estado _showHelp (1): "; grep -c "bool _showHelp" lib/main.dart
echo -n "  boton de ayuda (1): "; grep -c "Que significa esto?" lib/main.dart
echo -n "  texto EN (1): "; grep -c "What does this mean?" lib/main.dart
echo -n "  bug \$ (0): "; grep -c '\\\$' lib/main.dart || true
