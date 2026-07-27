#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p backups_widget
cp -v lib/widget_chart.dart "backups_widget/widget_chart.dart.bak_$TS"
cp -v lib/energy_cost.dart  "backups_widget/energy_cost.dart.bak_$TS"

cat > /tmp/patch_orden.py << 'PYEOF'
import sys, os, shutil

ROOT = os.path.expanduser('~/LP10')
TEST = '/tmp/pruebatest17'

WC = [("""  sb.writeln('Consumo por dia  obj ${_d1(kTargetKwh100)}');
  sb.writeln('dia' +
      'kWh100'.padLeft(7) +
      ' ' +
      'km'.padLeft(4) +
      (conEuro ? '\\u20AC'.padLeft(6) : ''));
""",
"""  // Ancho util medido en pantalla: 22 caracteres con monospace a 13sp. El
  // titulo anterior gastaba 25 y se partia en dos lineas.
  sb.writeln('Consumo dia  obj ${_d1(kTargetKwh100)}');
  // La cabecera tiene que cuadrar EXACTAMENTE con el reparto de las filas:
  //   dia(2) espacio(1) kWh(5) marca(1) km(4) euro(6) = 19 caracteres.
  sb.writeln('dia' +
      'kWh'.padLeft(5) +
      ' ' +
      'km'.padLeft(4) +
      (conEuro ? '\\u20AC'.padLeft(6) : ''));
""")]

EC = [("""    final kHoy = tHoy.eur, k7 = t7.eur, kMes = tMes.eur;

    // Coma decimal: el resto del widget ya la usa (_d1 en widget_chart.dart).
    String eur(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

    // Ancho: las lineas mas largas del grafico rondan los 25 caracteres
    // ("Consumo kWh/100  obj 15,6"). Estas se quedan en 19, asi que caben.
    final w = StringBuffer()
      ..writeln('Gasto hoy ' + eur(kHoy).padLeft(6) + ' \\u20AC')
      ..writeln('Gasto 7d  ' + eur(k7).padLeft(6) + ' \\u20AC')
      ..write('Gasto mes ' + eur(kMes).padLeft(6) + ' \\u20AC');
""",
"""    // Coma decimal: el resto del widget ya la usa (_d1 en widget_chart.dart).
    String eur(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    String km(double v) => v.toStringAsFixed(0);

    // Mismo ancho de 19 caracteres que la tabla diaria, para que las columnas
    // de km y euros queden en la misma vertical en todo el widget:
    //   etiqueta(7) km(5) euro(7).
    final w = StringBuffer()
      ..writeln('Totales' + 'km'.padLeft(5) + '\\u20AC'.padLeft(7))
      ..writeln('Hoy'.padRight(7) +
          km(tHoy.km).padLeft(5) +
          eur(tHoy.eur).padLeft(7))
      ..writeln('7 dias'.padRight(7) +
          km(t7.km).padLeft(5) +
          eur(t7.eur).padLeft(7))
      ..write('Mes'.padRight(7) +
          km(tMes.km).padLeft(5) +
          eur(tMes.eur).padLeft(7));
""")]

EDITS = {'lib/widget_chart.dart': WC, 'lib/energy_cost.dart': EC}

def bal(t):
    return (t.count('(') - t.count(')'),
            t.count('{') - t.count('}'),
            t.count('[') - t.count(']'))

def apply(base, write):
    ok = True
    for rel, pairs in EDITS.items():
        p = os.path.join(base, rel)
        src = open(p, encoding='utf-8').read()
        out, bad = src, False
        for i, (old, new) in enumerate(pairs):
            n = out.count(old)
            print("  %-24s ancla#%d -> %d" % (os.path.basename(rel), i + 1, n))
            if n != 1:
                print("     ABORTA"); ok = False; bad = True; break
            out = out.replace(old, new, 1)
        if bad:
            continue
        d = tuple(a - b for a, b in zip(bal(out), bal(src)))
        print("  %-24s balance %s" % (os.path.basename(rel), str(d)))
        if d != (0, 0, 0):
            print("     ABORTA: desbalance"); ok = False; continue
        if write:
            open(p, 'w', encoding='utf-8').write(out)
            print("     ESCRITO")
    return ok

mode = sys.argv[1]
if mode == 'dry':
    if os.path.isdir(TEST): shutil.rmtree(TEST)
    os.makedirs(os.path.join(TEST, 'lib'))
    for rel in EDITS:
        shutil.copy2(os.path.join(ROOT, rel), os.path.join(TEST, rel))
    print("--- DRY RUN")
    sys.exit(0 if apply(TEST, True) else 1)
else:
    print("--- APLICANDO")
    sys.exit(0 if apply(ROOT, True) else 1)
PYEOF

echo
echo "### DRY RUN"
python3 /tmp/patch_orden.py dry
echo
echo "### REAL"
python3 /tmp/patch_orden.py real

echo
echo "### VERIFICACION"
grep -n "Consumo dia  obj\|'kWh'.padLeft(5)" lib/widget_chart.dart
grep -n "Totales'" lib/energy_cost.dart
echo
echo "### SIMULACION DEL ANCHO"
python3 - << 'PYEOF'
def fila(dia, kwh, over, km, eur):
    return dia + kwh.rjust(5) + over + km.rjust(4) + eur.rjust(6)
print('|' + 'Consumo dia  obj 15,6'.ljust(22) + '|  <- 21 de 22')
print('|' + ('dia' + 'kWh'.rjust(5) + ' ' + 'km'.rjust(4) + '\u20AC'.rjust(6)).ljust(22) + '|')
for d, k, o, m, e in [('21', '14,2', ' ', '9', '0,17'),
                      ('25', '18,5', '>', '66', '1,59'),
                      ('27', '14,8', ' ', '57', '1,10')]:
    print('|' + fila(d + ' ', k, o, m, e).ljust(22) + '|')
print('|' + 'Media 7d 15,4  ~430 km'.ljust(22) + '|  <- 22 de 22')
print('|' + ('Totales' + 'km'.rjust(5) + '\u20AC'.rjust(7)).ljust(22) + '|')
for t, m, e in [('Hoy', '57', '1,10'), ('7 dias', '265', '5,72'), ('Mes', '399', '8,27')]:
    print('|' + (t.ljust(7) + m.rjust(5) + e.rjust(7)).ljust(22) + '|')
PYEOF
