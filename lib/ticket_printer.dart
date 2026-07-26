// ticket_printer.dart — Ticket termico de eficiencia del coche para RawBT.
//
// Formato: 32 columnas monoespaciadas, barras con bloque unicode.
// Datos del propio coche (no de Octopus): consumo kWh/100 km por dia +
// resumen de medias. Objetivo: ver de un vistazo que dias te pasas del
// objetivo de 15,6 kWh/100 (= 430 km por carga) para mejorar el consumo.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

const double kTicketBatteryKwh = 67.1;
const double kTicketMaxRangeKm = 430.0;
final double kTicketTarget = kTicketBatteryKwh / kTicketMaxRangeKm * 100.0; // 15,6

const _tStorage = FlutterSecureStorage();
const int _cols = 32;

class DayEff {
  final DateTime day;
  double km = 0;
  double socDrop = 0;
  double chargedKwh = 0;
  DayEff(this.day);
  double? get kwh100 {
    if (km <= 0 || socDrop <= 0) return null;
    // Red de seguridad: un dia con consumo implausible no se imprime.
    final pct = socDrop / km * 100;
    if (pct < 12.0 || pct > 70.0) return null;
    return socDrop * kTicketBatteryKwh / km;
  }
}

/// Construye el texto del ticket para el rango [from, to] (inclusive por dia).
Future<String> buildEfficiencyTicket({
  required DateTime from,
  required DateTime to,
  String? nickname,
}) async {
  final days = await _computeDays(from, to);
  final b = StringBuffer();

  String line(String s) => s.length > _cols ? s.substring(0, _cols) : s;
  String center(String s) {
    if (s.length >= _cols) return s.substring(0, _cols);
    final pad = (_cols - s.length) ~/ 2;
    return ' ' * pad + s;
  }

  String sep() => '-' * _cols;
  String dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  b.writeln(center('LMB10  EFICIENCIA'));
  if (nickname != null && nickname.trim().isNotEmpty) {
    b.writeln(center(nickname.trim()));
  }
  b.writeln(sep());
  b.writeln(line('Ciclo: ${dm(from)} a ${dm(to)}'));
  b.writeln(line('Objetivo: ${_d1(kTicketTarget)} kWh/100'));
  b.writeln(line('          (= 430 km/carga)'));
  b.writeln(sep());
  b.writeln('');

  final withData = days.where((d) => d.kwh100 != null).toList();
  final maxVal = withData.isEmpty
      ? kTicketTarget
      : withData.map((d) => d.kwh100!).reduce((a, x) => a > x ? a : x);
  const barMax = 8;

  var totalKm = 0.0, totalDrop = 0.0, totalCharged = 0.0, charges = 0;
  DayEff? best, worst;

  for (final d in days) {
    final v = d.kwh100;
    if (d.chargedKwh > 0.05) {
      totalCharged += d.chargedKwh;
      charges++;
    }
    if (v == null) {
      b.writeln(line('${dm(d.day)}        --'));
      continue;
    }
    totalKm += d.km;
    totalDrop += d.socDrop;
    best = (best == null || v < best!.kwh100!) ? d : best;
    worst = (worst == null || v > worst!.kwh100!) ? d : worst;

    final blocks = maxVal <= 0 ? 0 : (v / maxVal * barMax).round().clamp(0, barMax);
    final bar = '\u2588' * blocks + ' ' * (barMax - blocks);
    final over = v > kTicketTarget ? '>' : ' ';
    b.writeln(line('${dm(d.day)} $bar ${_pad5(v)}$over'));
  }

  b.writeln('');
  b.writeln(sep());
  final mediaAll = totalKm > 0 && totalDrop > 0
      ? totalDrop * kTicketBatteryKwh / totalKm
      : null;
  b.writeln(_kv('Media kWh/100:', mediaAll == null ? '--' : _d1(mediaAll)));
  if (mediaAll != null) {
    final estKm = (kTicketBatteryKwh / mediaAll * 100).round();
    b.writeln(_kv('Autonomia real:', '$estKm km'));
    final verdict = mediaAll <= kTicketTarget ? 'DENTRO objetivo' : 'SOBRE objetivo';
    b.writeln(_kv('Estado:', verdict));
  }
  if (best != null) {
    b.writeln(_kv('Mejor dia:', '${dm(best!.day)} ${_d1(best!.kwh100!)}'));
  }
  if (worst != null) {
    b.writeln(_kv('Peor dia:', '${dm(worst!.day)} ${_d1(worst!.kwh100!)}'));
  }
  b.writeln(_kv('Total km:', totalKm.round().toString()));
  final totalKwh = totalDrop / 100.0 * kTicketBatteryKwh;
  b.writeln(_kv('kWh consumidos:', _d1(totalKwh)));
  b.writeln(_kv('Cargas:', charges.toString()));
  if (totalCharged > 0.05) {
    b.writeln(_kv('kWh cargados:', _d1(totalCharged)));
  }
  b.writeln(sep());
  b.writeln(center('lmb10'));
  b.writeln('');
  b.writeln('');
  b.writeln('');
  return b.toString();
}

String _d1(num v) => v.toStringAsFixed(1).replaceAll('.', ',');
String _pad5(double v) => _d1(v).padLeft(5);
String _kv(String k, String v) {
  final avail = _cols - k.length;
  final val = v.length > avail ? v.substring(0, avail) : v;
  return k + val.padLeft(_cols - k.length);
}

Future<List<({int ts, int km, double soc})>> _readPermanentTripsT() async {
  final out = <({int ts, int km, double soc})>[];
  try {
    final base = await getApplicationDocumentsDirectory();
    final f = File('${base.path}/lmb10_history/trips.jsonl');
    if (!await f.exists()) return out;
    for (final line in await f.readAsLines()) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(json.decode(t) as Map);
        if (m['ts'] is int && m['km'] is int && m['soc'] is num) {
          out.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
        }
      } catch (_) {}
    }
    out.sort((a, b) => a.ts.compareTo(b.ts));
  } catch (_) {}
  return out;
}

Future<List<DayEff>> _computeDays(DateTime from, DateTime to) async {
  final chargeRaw = await _tStorage.read(key: 'lm_charge_history_v1');

  var points = await _readPermanentTripsT();
  if (points.isEmpty) {
    final tripRaw = await _tStorage.read(key: 'lm_trip_points_v1');
    if (tripRaw != null) {
      for (final e in (json.decode(tripRaw) as List)) {
        final m = Map<String, dynamic>.from(e as Map);
        points.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
      }
    }
  }
  final sessions = <({int startTs, int? endTs, double startSoc, double? endSoc})>[];
  if (chargeRaw != null) {
    for (final e in (json.decode(chargeRaw) as List)) {
      final m = Map<String, dynamic>.from(e as Map);
      sessions.add((
        startTs: m['startTs'] as int,
        endTs: m['endTs'] as int?,
        startSoc: (m['startSoc'] as num).toDouble(),
        endSoc: (m['endSoc'] as num?)?.toDouble(),
      ));
    }
  }

  final d0 = DateTime(from.year, from.month, from.day);
  final d1 = DateTime(to.year, to.month, to.day);
  final map = <String, DayEff>{};
  final order = <String>[];
  for (var d = d0; !d.isAfter(d1); d = d.add(const Duration(days: 1))) {
    final key = '${d.year}-${d.month}-${d.day}';
    map[key] = DayEff(d);
    order.add(key);
  }
  String keyOf(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.year}-${d.month}-${d.day}';
  }

  for (var i = 1; i < points.length; i++) {
    final prev = points[i - 1], curr = points[i];
    final kmDelta = (curr.km - prev.km).toDouble();
    final socDelta = prev.soc - curr.soc;
    if (kmDelta <= 0 || socDelta <= 0) continue;
    // Cordura: descartar solo tramos fisicamente imposibles.
    final pct = socDelta / kmDelta * 100;
    if (pct < 8.0 || pct > 70.0) continue;
    final bar = map[keyOf(curr.ts)];
    if (bar == null) continue;
    bar.km += kmDelta;
    bar.socDrop += socDelta;
  }
  for (final s in sessions) {
    if (s.endTs != null && s.endSoc != null && (s.endSoc! - s.startSoc) >= 1.0) {
      final bar = map[keyOf(s.endTs!)];
      if (bar != null) bar.chargedKwh += (s.endSoc! - s.startSoc) / 100.0 * kTicketBatteryKwh;
    }
  }
  return order.map((k) => map[k]!).toList();
}

class TicketPrinter {
  static const _channel = MethodChannel('lmb10/rawbt');

  /// Intenta imprimir por RawBT. Si no esta o falla, abre la hoja de compartir.
  static Future<bool> printOrShare(String ticket) async {
    try {
      final ok = await _channel.invokeMethod<bool>('printRawBT', {'text': ticket});
      if (ok == true) return true;
    } catch (_) {}
    try {
      final dir = Directory.systemTemp;
      final f = File('${dir.path}/lmb10_ticket.txt');
      await f.writeAsString(ticket);
      await Share.shareXFiles([XFile(f.path)], text: 'Ticket LMB10');
      return true;
    } catch (_) {
      return false;
    }
  }
}
