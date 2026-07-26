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

# 1. Quitar el case 'export' entero
old_case = '''                case 'export':
                  final ok = await exportHistoryAndShare();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? (es ? 'Backup generado' : 'Backup created') : (es ? 'No se pudo exportar' : 'Export failed'))),
                  );
                  break;
'''
if s.count(old_case) != 1:
    sys.exit("ABORT: ancla case export x%d" % s.count(old_case))
s = s.replace(old_case, "", 1)

# 2. Quitar el PopupMenuItem de export (renombrado a compartir anonimo)
old_item = '''                PopupMenuItem(value: 'export', child: ListTile(dense: true, leading: const Icon(Icons.download), title: Text(es ? 'Compartir datos (anonimo)' : 'Share data (anonymous)')))'''
# puede o no tener coma al final segun quedo; probamos con coma
cand1 = old_item + ",\n"
cand2 = old_item + "\n"
if s.count(cand1) == 1:
    s = s.replace(cand1, "", 1)
elif s.count(cand2) == 1:
    s = s.replace(cand2, "", 1)
else:
    sys.exit("ABORT: ancla PopupMenuItem export (con=%d, sin=%d)" % (s.count(cand1), s.count(cand2)))

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] main.dart: 'Compartir datos' eliminado del menu")

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

echo "[i] Dry-run OK. Aplicando..."
cp /tmp/pruebatest/main.dart lib/main.dart

echo "[i] Verificacion:"
echo -n "  case export fuera (0): "; grep -c "case 'export':" lib/main.dart
echo -n "  item compartir fuera (0): "; grep -c "Compartir datos (anonimo)" lib/main.dart
echo -n "  value export fuera (0): "; grep -c "value: 'export'" lib/main.dart

echo
echo "[i] Nota: la funcion exportHistoryAndShare() y exportAnonymizedJson()"
echo "    quedan en el codigo pero ya sin usar. El tree-shaking las elimina"
echo "    del build. Si quieres borrarlas del fuente tambien, dime y lo hago."
