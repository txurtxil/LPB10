#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp lib/settings_screen.dart backups_widget/settings_screen.dart.bak_$TS
echo "[i] Backups en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart
cp lib/settings_screen.dart /tmp/pruebatest/settings_screen.dart

python3 - <<'PYEOF'
import io, sys

# --- 1. Quitar el IconButton de log de la barra en main.dart ---
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()
old = '''          IconButton(
            icon: const Icon(Icons.article_outlined),
            tooltip: 'Log del coche',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarLogScreen())),
          ),
'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla icono barra x%d" % s.count(old))
s = s.replace(old, "", 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] main.dart: icono de log quitado de la barra")

# --- 2. Añadir fila de log en settings_screen.dart ---
p = "/tmp/pruebatest/settings_screen.dart"
t = io.open(p, encoding='utf-8').read()

# import de CarLogScreen
if "car_log_screen.dart" not in t:
    t = t.replace(
        "import 'package:flutter_secure_storage/flutter_secure_storage.dart';",
        "import 'package:flutter_secure_storage/flutter_secure_storage.dart';\nimport 'car_log_screen.dart';", 1)

# Añadir ListTile tras el SwitchListTile del mapa
anchor = '''                  onChanged: (v) async {
                    setState(() => _showMap = v);
                    await _storage.write(key: showMapKey, value: v ? '1' : '0');
                  },
                ),'''
if t.count(anchor) != 1:
    sys.exit("ABORT: ancla switch mapa x%d" % t.count(anchor))
newrow = anchor + '''
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Log del coche (Android Auto)'
                      : 'Car log (Android Auto)'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Diagnostico de la conexion con el coche'
                      : 'Diagnostics for the car connection'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CarLogScreen())),
                ),'''
t = t.replace(anchor, newrow, 1)
io.open(p, 'w', encoding='utf-8').write(t)
print("[ok] settings_screen.dart: fila de log añadida")

# Balance
for f in [d, p]:
    x = io.open(f, encoding='utf-8').read()
    for op,cl,n in [('(',')','par'),('{','}','lla')]:
        print("  [dry] %s %s diff=%d" % (f.split('/')[-1], n, x.count(op)-x.count(cl)))
PYEOF

# Balance preservado
python3 -c "
import io
for real,test in [('lib/main.dart','/tmp/pruebatest/main.dart'),('lib/settings_screen.dart','/tmp/pruebatest/settings_screen.dart')]:
    o=io.open(real,encoding='utf-8').read(); n=io.open(test,encoding='utf-8').read()
    for op,cl in [('(',')'),('{','}')]:
        assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op+' en '+real
print('[dry] balance preservado en ambos')
"

echo "[i] Dry-run OK. Aplicando..."
cp /tmp/pruebatest/main.dart lib/main.dart
cp /tmp/pruebatest/settings_screen.dart lib/settings_screen.dart

echo "[i] Verificacion:"
echo -n "  icono fuera de barra (article en main, debe ser 0): "; grep -c "article_outlined" lib/main.dart
echo -n "  fila en ajustes (debe ser 1): "; grep -c "article_outlined" lib/settings_screen.dart
echo -n "  import CarLogScreen en settings: "; grep -c "car_log_screen" lib/settings_screen.dart
