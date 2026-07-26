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

# ================= main.dart =================
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

# 1. Quitar el case 'import' entero
old_case = '''                case 'import':
                  final msg = await importHistoryBackup();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  _loadStatus();
                  break;
'''
if s.count(old_case) != 1:
    sys.exit("ABORT: ancla case import x%d" % s.count(old_case))
s = s.replace(old_case, "", 1)

# 2. Quitar el PopupMenuItem de import
old_item = '''                PopupMenuItem(value: 'import', child: ListTile(dense: true, leading: const Icon(Icons.upload), title: Text(es ? 'Importar backup' : 'Import backup'))),
'''
if s.count(old_item) != 1:
    sys.exit("ABORT: ancla PopupMenuItem import x%d" % s.count(old_item))
s = s.replace(old_item, "", 1)

# 3. Renombrar "Exportar historico" -> "Compartir datos (anonimo)"
old_exp = '''title: Text(es ?
'Exportar historico' : 'Export history')))'''
# ese salto de linea es del volcado; probamos ambas formas
if old_exp not in s:
    old_exp = "title: Text(es ? 'Exportar historico' : 'Export history')))"
if s.count(old_exp) != 1:
    sys.exit("ABORT: ancla texto export x%d (revisar)" % s.count(old_exp))
s = s.replace(old_exp,
    "title: Text(es ? 'Compartir datos (anonimo)' : 'Share data (anonymous)')))", 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] main.dart: import fuera del menu, export renombrado a compartir anonimo")

# ================= settings_screen.dart =================
p = "/tmp/pruebatest/settings_screen.dart"
t = io.open(p, encoding='utf-8').read()

# import de importHistoryBackup (esta en history_archive.dart)
if "history_archive.dart" not in t:
    t = t.replace("import 'car_log_screen.dart';",
                  "import 'car_log_screen.dart';\nimport 'history_archive.dart';", 1)

# Insertar "Importar copia" tras el ListTile de exportar (antes del Padding del aviso)
anchor = '''                  onTap: () async {
                    try {
                      final path = await BackupHelper.writeNow();
                      await Share.shareXFiles([XFile(path)], text: 'LMB10 backup');
                    } catch (_) {}
                  },
                ),
                Padding('''
if t.count(anchor) != 1:
    sys.exit("ABORT: ancla export settings x%d" % t.count(anchor))

new_import_row = '''                  onTap: () async {
                    try {
                      final path = await BackupHelper.writeNow();
                      await Share.shareXFiles([XFile(path)], text: 'LMB10 backup');
                    } catch (_) {}
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Importar copia de seguridad'
                      : 'Import backup'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Restaura tu historico desde un archivo exportado'
                      : 'Restore your history from an exported file'),
                  trailing: const Icon(Icons.folder_open),
                  onTap: () async {
                    final msg = await importHistoryBackup();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)));
                  },
                ),
                Padding('''
t = t.replace(anchor, new_import_row, 1)
io.open(p, 'w', encoding='utf-8').write(t)
print("[ok] settings_screen.dart: importar copia añadido junto al exportar")

# Balance
for f in [d, p]:
    x = io.open(f, encoding='utf-8').read()
    for op,cl,n in [('(',')','par'),('{','}','lla')]:
        print("  [dry] %s %s diff=%d" % (f.split('/')[-1], n, x.count(op)-x.count(cl)))
PYEOF

python3 -c "
import io
for real,test in [('lib/main.dart','/tmp/pruebatest/main.dart'),('lib/settings_screen.dart','/tmp/pruebatest/settings_screen.dart')]:
    o=io.open(real,encoding='utf-8').read(); n=io.open(test,encoding='utf-8').read()
    for op,cl in [('(',')'),('{','}')]:
        assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op+' en '+real
print('[dry] balance preservado')
"

echo "[i] Dry-run OK. Aplicando..."
cp /tmp/pruebatest/main.dart lib/main.dart
cp /tmp/pruebatest/settings_screen.dart lib/settings_screen.dart

echo "[i] Verificacion:"
echo -n "  import fuera del menu (0): "; grep -c "value: 'import'" lib/main.dart
echo -n "  case import fuera (0): "; grep -c "case 'import':" lib/main.dart
echo -n "  compartir anonimo (1): "; grep -c "Compartir datos (anonimo)" lib/main.dart
echo -n "  importar en ajustes (1): "; grep -c "Importar copia de seguridad" lib/settings_screen.dart
echo -n "  import history_archive en settings (1): "; grep -c "history_archive.dart" lib/settings_screen.dart
echo -n "  bug \$ main (0): "; grep -c '\\\$' lib/main.dart || true
echo -n "  bug \$ settings (0): "; grep -c '\\\$' lib/settings_screen.dart || true
