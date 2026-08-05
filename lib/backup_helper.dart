import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'history_archive.dart';

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
    // Formato COMPATIBLE con importHistoryBackup(): claves tripPoints y
    // chargeSessions, con los mismos campos que espera el importador.
    final trips = <Map<String, dynamic>>[];
    final charges = <Map<String, dynamic>>[];
    try {
      final t = File('${docs.path}/lmb10_history/trips.jsonl');
      if (await t.exists()) {
        for (final line in await t.readAsLines()) {
          final s = line.trim();
          if (s.isEmpty) continue;
          try {
            final m = Map<String, dynamic>.from(json.decode(s) as Map);
            if (m['ts'] is int && m['km'] is int && m['soc'] is num) {
              trips.add({'ts': m['ts'], 'km': m['km'], 'soc': m['soc']});
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    try {
      final c = File('${docs.path}/lmb10_history/charges.jsonl');
      if (await c.exists()) {
        for (final line in await c.readAsLines()) {
          final s = line.trim();
          if (s.isEmpty) continue;
          try {
            final m = Map<String, dynamic>.from(json.decode(s) as Map);
            if (m['startTs'] is int && m['startSoc'] is num) {
              charges.add({
                'startTs': m['startTs'],
                'endTs': m['endTs'],
                'startSoc': m['startSoc'],
                'endSoc': m['endSoc'],
              });
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'ajustes': await ajustesParaBackup(),
      'tripPoints': trips,
      'chargeSessions': charges,
    };
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
