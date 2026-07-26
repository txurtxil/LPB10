// history_archive.dart - Historico permanente (JSONL) y exportacion.
// Los stores de la app capan a 200 puntos / 25 sesiones; este archivo
// guarda TODO sin limite en Documents/lmb10_history/ y permite exportar
// backup JSON + CSVs (separador ';', decimales con coma para Excel ES).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';

const _haStorage = FlutterSecureStorage();
const double _haBatteryKwh = 67.1;

class HistoryArchive {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/lmb10_history');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<void> appendTrip(int ts, int km, double soc) async {
    try {
      final d = await _dir();
      final f = File('${d.path}/trips.jsonl');
      await f.writeAsString(
          '${json.encode({'ts': ts, 'km': km, 'soc': soc})}\n',
          mode: FileMode.append,
          flush: true);
    } catch (_) {}
  }

  static Future<void> appendCharge(
      int startTs, int endTs, double startSoc, double endSoc) async {
    try {
      final d = await _dir();
      final f = File('${d.path}/charges.jsonl');
      await f.writeAsString(
          '${json.encode({
                'startTs': startTs,
                'endTs': endTs,
                'startSoc': startSoc,
                'endSoc': endSoc
              })}\n',
          mode: FileMode.append,
          flush: true);
    } catch (_) {}
  }
}

Future<List<Map<String, dynamic>>> _readJsonl(String path) async {
  final f = File(path);
  if (!await f.exists()) return [];
  final out = <Map<String, dynamic>>[];
  for (final line in await f.readAsLines()) {
    final l = line.trim();
    if (l.isEmpty) continue;
    try {
      out.add(Map<String, dynamic>.from(json.decode(l) as Map));
    } catch (_) {}
  }
  return out;
}

String _iso(int ms) =>
    DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();

String _dec(num v) => v.toStringAsFixed(1).replaceAll('.', ',');

String _stamp() {
  final n = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
}

/// Genera backup JSON + CSVs y abre la hoja de compartir. true si todo OK.
Future<bool> exportHistoryAndShare() async {
  try {
    final dir = await HistoryArchive._dir();

    // Fuentes: archivo permanente + stores actuales
    final tripArch = await _readJsonl('${dir.path}/trips.jsonl');
    final chargeArch = await _readJsonl('${dir.path}/charges.jsonl');

    List<Map<String, dynamic>> fromStore(String? raw) => raw == null
        ? <Map<String, dynamic>>[]
        : (json.decode(raw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    final curTrips =
        fromStore(await _haStorage.read(key: 'lm_trip_points_v1'));
    final curCharges =
        fromStore(await _haStorage.read(key: 'lm_charge_history_v1'));

    // Viajes: fusion por ts, sin duplicados
    final tripMap = <int, Map<String, dynamic>>{};
    for (final t in [...tripArch, ...curTrips]) {
      final ts = t['ts'];
      if (ts is int) tripMap[ts] = t;
    }
    final trips = tripMap.values.toList()
      ..sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));

    // Cargas: archivo + actuales cerradas con ganancia >= 1%
    final chMap = <int, Map<String, dynamic>>{};
    for (final c in chargeArch) {
      final ts = c['startTs'];
      if (ts is int) chMap[ts] = c;
    }
    for (final c in curCharges) {
      final end = c['endTs'];
      final endSoc = c['endSoc'];
      final startSoc = c['startSoc'];
      if (end != null &&
          endSoc is num &&
          startSoc is num &&
          endSoc - startSoc >= 1.0) {
        chMap[c['startTs'] as int] = c;
      }
    }
    final charges = chMap.values.toList()
      ..sort((a, b) => (a['startTs'] as int).compareTo(b['startTs'] as int));

    // Ficheros de salida
    final exDir = Directory('${dir.path}/export');
    if (!await exDir.exists()) await exDir.create(recursive: true);
    final stamp = _stamp();

    final fJson = File('${exDir.path}/LMB10_backup_$stamp.json');
    await fJson.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'app': 'LMB10',
      'exportedAt': DateTime.now().toIso8601String(),
      'batteryKwh': _haBatteryKwh,
      'tripPoints': trips,
      'chargeSessions': charges,
    }));

    final fT = File('${exDir.path}/LMB10_viajes_$stamp.csv');
    final tBuf = StringBuffer('fecha;odometro_km;soc_%\n');
    for (final t in trips) {
      tBuf.writeln(
          '${_iso(t['ts'] as int)};${t['km']};${_dec(t['soc'] as num)}');
    }
    await fT.writeAsString(tBuf.toString());

    final fC = File('${exDir.path}/LMB10_cargas_$stamp.csv');
    final cBuf = StringBuffer(
        'inicio;fin;soc_inicial_%;soc_final_%;ganancia_%;kwh_estimados\n');
    for (final c in charges) {
      final g = (c['endSoc'] as num) - (c['startSoc'] as num);
      cBuf.writeln('${_iso(c['startTs'] as int)};${_iso(c['endTs'] as int)};'
          '${_dec(c['startSoc'] as num)};${_dec(c['endSoc'] as num)};'
          '${_dec(g)};${_dec(g / 100 * _haBatteryKwh)}');
    }
    await fC.writeAsString(cBuf.toString());

    await Share.shareXFiles(
      [XFile(fJson.path), XFile(fT.path), XFile(fC.path)],
      text: 'Backup LMB10 $stamp',
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// Importa un backup JSON generado por "Exportar historico": restaura los
/// stores de la app (ultimos 200 puntos / 25 cargas) y lo vuelca entero al
/// archivo permanente. Devuelve el mensaje para el SnackBar.
Future<String> importHistoryBackup() async {
  try {
    const grupo = XTypeGroup(label: 'Backup JSON', extensions: ['json']);
    final XFile? file = await openFile(acceptedTypeGroups: [grupo]);
    if (file == null) return 'Importacion cancelada';
    final content = await file.readAsString();

    final map = Map<String, dynamic>.from(json.decode(content) as Map);
    final tp = (map['tripPoints'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => m['ts'] is int && m['km'] is int && m['soc'] is num)
        .toList()
      ..sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
    final ch = (map['chargeSessions'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((m) => m['startTs'] is int && m['startSoc'] is num)
        .toList()
      ..sort((a, b) => (a['startTs'] as int).compareTo(b['startTs'] as int));
    if (tp.isEmpty && ch.isEmpty) return 'Backup sin datos reconocibles';

    // Deduplicacion contra lo que YA hay en disco.
    //
    // El comentario que habia aqui decia que la exportacion deduplica por
    // timestamp. NO es cierto: un backup real del 26/07/2026 traia 2777
    // entradas con 1212 duplicados exactos, y todo lo anterior al 20/07
    // aparecia escrito TRES veces. La causa era esta misma funcion: appendTrip
    // a pelo, sin comprobar si la linea ya existia, ejecutada mas de una vez
    // sobre datos que ya se estaban recogiendo.
    //
    // Filtrando aqui, la importacion pasa a ser idempotente: importar dos
    // veces el mismo fichero no cambia nada.
    String claveTrip(Map<String, dynamic> m) {
      final ts = m['ts'];
      final km = m['km'];
      final soc = m['soc'];
      if (ts is! int || km is! int || soc is! num) return '';
      return ts.toString() +
          ':' +
          km.toString() +
          ':' +
          soc.toDouble().toString();
    }

    final dir = await HistoryArchive._dir();

    final yaTrips = <String>{};
    final fTrips = File(dir.path + '/trips.jsonl');
    if (await fTrips.exists()) {
      for (final linea in await fTrips.readAsLines()) {
        final s = linea.trim();
        if (s.isEmpty) continue;
        try {
          final k = claveTrip(
              Map<String, dynamic>.from(json.decode(s) as Map));
          if (k.isNotEmpty) yaTrips.add(k);
        } catch (_) {}
      }
    }

    final yaCargas = <String>{};
    final fCargas = File(dir.path + '/charges.jsonl');
    if (await fCargas.exists()) {
      for (final linea in await fCargas.readAsLines()) {
        final s = linea.trim();
        if (s.isEmpty) continue;
        try {
          final m = Map<String, dynamic>.from(json.decode(s) as Map);
          yaCargas.add(m['startTs'].toString() + ':' + m['endTs'].toString());
        } catch (_) {}
      }
    }

    var nuevosTrips = 0;
    var repes = 0;
    for (final t in tp) {
      final k = claveTrip(t);
      if (k.isEmpty) continue;
      if (!yaTrips.add(k)) {
        repes++;
        continue;
      }
      await HistoryArchive.appendTrip(
          t['ts'] as int, t['km'] as int, (t['soc'] as num).toDouble());
      nuevosTrips++;
    }

    var nuevasCargas = 0;
    for (final c in ch) {
      final endV = c['endTs'];
      final socV = c['endSoc'];
      if (endV is int && socV is num) {
        if (!yaCargas.add(c['startTs'].toString() + ':' + endV.toString())) {
          repes++;
          continue;
        }
        await HistoryArchive.appendCharge(c['startTs'] as int, endV,
            (c['startSoc'] as num).toDouble(), socV.toDouble());
        nuevasCargas++;
      }
    }

    // Stores de la app
    final tpStore = tp.length > 200 ? tp.sublist(tp.length - 200) : tp;
    final chStore = ch.length > 25 ? ch.sublist(ch.length - 25) : ch;
    await _haStorage.write(
        key: 'lm_trip_points_v1',
        value: json.encode(tpStore
            .map((t) => {'ts': t['ts'], 'km': t['km'], 'soc': t['soc']})
            .toList()));
    await _haStorage.write(
        key: 'lm_charge_history_v1',
        value: json.encode(chStore
            .map((c) => {
                  'startTs': c['startTs'],
                  'endTs': c['endTs'],
                  'startSoc': c['startSoc'],
                  'endSoc': c['endSoc']
                })
            .toList()));
    return 'Importado: ' +
        nuevosTrips.toString() +
        ' puntos, ' +
        nuevasCargas.toString() +
        ' cargas' +
        (repes > 0 ? ' (' + repes.toString() + ' ya estaban, omitidos)' : '');
  } catch (_) {
    return 'Backup no valido';
  }
}
