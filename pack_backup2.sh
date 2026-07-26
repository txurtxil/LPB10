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

# ============ 1. backup_helper.dart ============
helper = '''import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

/// Copia de seguridad automatica del historico a una carpeta accesible.
/// Ruta: /Android/data/com.txurtxil.lpb10/files/backups/ (sin permisos).
/// AVISO: esta carpeta se BORRA al desinstalar la app.
class BackupHelper {
  static const _lastBackupKey = 'lm_last_auto_backup_ms';

  static Future<Directory> _backupDir() async {
    final ext = await getExternalStorageDirectory();
    final base = ext ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Map<String, dynamic>> _collect() async {
    final docs = await getApplicationDocumentsDirectory();
    final out = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'trips': <String>[],
      'charges': <String>[],
    };
    try {
      final t = File('${docs.path}/lmb10_history/trips.jsonl');
      if (await t.exists()) out['trips'] = await t.readAsLines();
    } catch (_) {}
    try {
      final c = File('${docs.path}/lmb10_history/charges.jsonl');
      if (await c.exists()) out['charges'] = await c.readAsLines();
    } catch (_) {}
    return out;
  }

  static Future<String> writeNow() async {
    final dir = await _backupDir();
    final data = await _collect();
    final f = File('${dir.path}/lmb10_backup.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return f.path;
  }

  static Future<void> autoBackupIfDue(
      Future<String?> Function(String) readPref,
      Future<void> Function(String, String) writePref) async {
    try {
      final lastRaw = await readPref(_lastBackupKey);
      final last = int.tryParse(lastRaw ?? '') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 24 * 3600 * 1000) return;
      await writeNow();
      await writePref(_lastBackupKey, now.toString());
    } catch (_) {}
  }
}
'''
io.open("/tmp/pruebatest/backup_helper.dart", 'w', encoding='utf-8').write(helper)
print("[ok] backup_helper.dart creado")

# ============ 2. Enganchar en el executeTask (linea 123, ancla amplia) ============
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

if "backup_helper.dart" not in s:
    s = s.replace("import 'settings_screen.dart';",
                  "import 'settings_screen.dart';\nimport 'backup_helper.dart';", 1)

# Ancla UNICA: la del dispatcher del WorkManager (con executeTask alrededor)
anchor = '''  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshVehicleDataInBackground();
      return true;'''
if s.count(anchor) != 1:
    sys.exit("ABORT: ancla executeTask x%d" % s.count(anchor))
s = s.replace(anchor,
'''  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshVehicleDataInBackground();
      // Copia de seguridad automatica diaria (best-effort).
      await BackupHelper.autoBackupIfDue(
        (k) => _storage.read(key: k),
        (k, v) => _storage.write(key: k, value: v),
      );
      return true;''', 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] main.dart: backup diario en el WorkManager")

# ============ 3. Ajustes: boton exportar + aviso ============
p = "/tmp/pruebatest/settings_screen.dart"
t = io.open(p, encoding='utf-8').read()

for imp in ["import 'backup_helper.dart';",
            "import 'package:share_plus/share_plus.dart';",
            "import 'dart:io';"]:
    token = imp.split("'")[1]
    if token not in t:
        t = t.replace("import 'car_log_screen.dart';",
                      "import 'car_log_screen.dart';\n" + imp, 1)

anchor = '''                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CarLogScreen())),
                ),'''
if t.count(anchor) != 1:
    sys.exit("ABORT: ancla fila log x%d" % t.count(anchor))
newblock = anchor + '''
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Exportar copia de seguridad'
                      : 'Export backup'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Comparte un archivo con tu historico (cargas y viajes)'
                      : 'Share a file with your history (charges and trips)'),
                  trailing: const Icon(Icons.share),
                  onTap: () async {
                    try {
                      final path = await BackupHelper.writeNow();
                      await Share.shareXFiles([XFile(path)], text: 'LMB10 backup');
                    } catch (_) {}
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'es'
                        ? 'La app guarda una copia automatica cada dia en su carpeta de archivos. IMPORTANTE: esa copia se borra si desinstalas la app. Antes de desinstalar, exporta tu copia con el boton de arriba y guardala donde quieras (Drive, Telegram, etc.).'
                        : 'The app saves an automatic daily backup in its files folder. IMPORTANT: that copy is deleted if you uninstall the app. Before uninstalling, export your backup with the button above and save it somewhere safe (Drive, Telegram, etc.).',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),'''
t = t.replace(anchor, newblock, 1)
io.open(p, 'w', encoding='utf-8').write(t)
print("[ok] settings_screen.dart: boton exportar + aviso")

for f in [d, p, "/tmp/pruebatest/backup_helper.dart"]:
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
cp /tmp/pruebatest/backup_helper.dart lib/backup_helper.dart
cp /tmp/pruebatest/main.dart lib/main.dart
cp /tmp/pruebatest/settings_screen.dart lib/settings_screen.dart

echo "[i] Verificacion:"
echo -n "  backup_helper existe: "; ls lib/backup_helper.dart >/dev/null 2>&1 && echo OK
echo -n "  autoBackup en main (1): "; grep -c "autoBackupIfDue" lib/main.dart
echo -n "  boton exportar (1): "; grep -c "backup_outlined" lib/settings_screen.dart
echo -n "  aviso desinstalar (1): "; grep -c "se borra si desinstalas" lib/settings_screen.dart
echo -n "  bug \$ main (0): "; grep -c '\\\$' lib/main.dart || true
echo -n "  bug \$ helper (0): "; grep -c '\\\$' lib/backup_helper.dart || true
