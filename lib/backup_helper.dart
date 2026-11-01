import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'history_archive.dart';

/// Copia de seguridad automatica del historico a una carpeta accesible.
/// Ruta en Android: /Android/data/com.txurtxil.lpb10/files/backups/ (sin
/// permisos). En iOS: Documents/backups de la app (visible desde la app
/// Archivos si se declara; si no, accesible al compartir el fichero).
/// AVISO: esta carpeta se BORRA al desinstalar la app.
class BackupHelper {
  static const _lastBackupKey = 'lm_last_auto_backup_ms';

  static Future<Directory> _backupDir() async {
    // getExternalStorageDirectory NO existe en iOS: no devuelve null, LANZA
    // (UnsupportedError/MissingPluginException), y el catch de quien llama se
    // lo tragaba en silencio. Resultado: exportar backup y el backup local
    // automatico estaban rotos en iOS desde el principio (v158).
    Directory? ext;
    if (Platform.isAndroid) {
      ext = await getExternalStorageDirectory();
    }
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

  /// Version del JSON como String, para subir a Drive sin pasar por disco
  /// local primero. Reutiliza _collect(), no reinventa el formato.
  // v239: canal nativo para elegir carpeta (SAF) y escribir la copia en
  // una ubicacion del usuario que sobrevive a la desinstalacion.
  static const MethodChannel _ch = MethodChannel('lmb10/backup');
  static const String folderKey = 'lm_backup_folder_uri';
  static const String intervalKey = 'lm_backup_interval_days';

  /// Carpeta elegida (persistida en secure storage; si no, la del canal).
  static Future<String?> folderActual(
      Future<String?> Function(String) readPref) async {
    try {
      final saved = await readPref(folderKey);
      if (saved != null && saved.isNotEmpty) return saved;
      return await _ch.invokeMethod<String>('getFolder');
    } catch (_) {
      return null;
    }
  }

  /// Abre el selector SAF de carpeta (requiere actividad en primer plano).
  static Future<String?> elegirCarpeta() async {
    try {
      return await _ch.invokeMethod<String>('pickFolder');
    } catch (_) {
      return null;
    }
  }

  static Future<bool> quitarCarpeta() async {
    try {
      return await _ch.invokeMethod<bool>('clearFolder') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _escribirEnCarpeta(String uri) async {
    try {
      return await _ch.invokeMethod<bool>('writeBackup', {
            'uri': uri,
            'fileName': 'lmb10_backup.json',
            'content': await contenidoJson(),
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<String> contenidoParaSubir() async {
    final data = await _collect();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Future<String> writeNow() async {
    final dir = await _backupDir();
    final data = await _collect();
    final f = File('${dir.path}/lmb10_backup.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return f.path;
  }

  /// Intervalo en dias (por defecto 1 = diario).
  static Future<int> intervaloDias(
      Future<String?> Function(String) readPref) async {
    final d = int.tryParse((await readPref(intervalKey)) ?? '');
    return (d == null || d < 1) ? 1 : d;
  }

  static Future<String> contenidoJson() async =>
      const JsonEncoder.withIndent('  ').convert(await _collect());

  static Future<void> autoBackupIfDue(
      Future<String?> Function(String) readPref,
      Future<void> Function(String, String) writePref) async {
    try {
      final lastRaw = await readPref(_lastBackupKey);
      final last = int.tryParse(lastRaw ?? '') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final dias = await intervaloDias(readPref);
      if (now - last < dias * 24 * 3600 * 1000) return;
      // v239: si hay carpeta elegida (SAF), escribir alli.
      final folder = await folderActual(readPref);
      if (folder != null && await _escribirEnCarpeta(folder)) {
        await writePref(_lastBackupKey, now.toString());
        return;
      }
      await writeNow();
      await writePref(_lastBackupKey, now.toString());
    } catch (_) {}
  }
}
