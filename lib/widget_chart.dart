// widget_chart.dart v2 - Grafico de consumo diario para el widget de inicio.
//
// Barras: kWh/100 km por dia (7 dias) desde odometro + SOC.
//   VERDE  = dia con consumo <= 15,6 (a ritmo de 430 km por carga)
//   NARANJA= dia por encima del objetivo
// Linea roja discontinua: 15,6 kWh/100 km = 67,1 kWh / 430 km.
// Rayo + "+X,X" = kWh cargados ese dia. Arriba: leyenda y media semanal
// con km/carga estimados. Devuelve ademas 'realRange' (autonomia real
// estimada al SOC actual segun tu consumo medio de la semana).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

// Ya NO son const: las fija loadVehicleProfile() al arrancar segun el modelo
// elegido por el usuario. Los valores de aqui son solo el punto de partida
// (B10) para quien nunca haya tocado el perfil.
double gBatteryKwh = 67.1;
double gMaxRangeKm = 430.0;

// GETTER, no final. Un final de nivel superior se calcula UNA sola vez en su
// primera lectura, asi que si el perfil se carga despues se quedaria clavado
// en el objetivo del B10 para siempre.
double get kTargetKwh100 => gBatteryKwh / gMaxRangeKm * 100.0;

const _wcStorage = FlutterSecureStorage();
const _kTripKey = 'lm_trip_points_v1';
const _kChargeKey = 'lm_charge_history_v1';

const _cBlue = Color(0xFF0D3B66);
const _cGood = Color(0xFF2A9D8F); // <= objetivo
const _cOver = Color(0xFFE76F51); // > objetivo
const _cLine = Color(0xFFE63946); // linea 430 km

class _DayBar {
  final String label;
  double km = 0;
  double socDrop = 0;
  bool charged = false;
  double chargedKwh = 0;
  _DayBar(this.label);
  double? get kwh100 {
    if (km <= 0 || socDrop <= 0) return null;
    // Red de seguridad: un dia con consumo implausible no se pinta.
    final pct = socDrop / km * 100;
    if (pct < 12.0 || pct > 70.0) return null;
    return socDrop * gBatteryKwh / km;
  }
}

String _d1(num v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Lee los puntos de viaje del archivo permanente (Documents/lmb10_history/
/// trips.jsonl), que guarda TODO sin el limite de 200 del store rapido.
/// Devuelve lista vacia si no existe o no se puede leer.
Future<List<({int ts, int km, double soc})>> _readPermanentTrips() async {
  final out = <({int ts, int km, double soc})>[];
  try {
    final base = await getApplicationDocumentsDirectory();
    final f = File('${base.path}/lmb10_history/trips.jsonl');
    if (!await f.exists()) return out;
    final lines = await f.readAsLines();
    for (final line in lines) {
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

Future<Map<String, String>> buildWidgetExtras(
    {required bool isCharging, double? socPercent, double? eurKwh}) async {
  String lastCharge = '';
  String chartPath = '';
  String chartText = '';
  String realRange = '';
  String cycleKm = '';
  try {
    // ---------- datos locales ----------
    final chargeRaw = await _wcStorage.read(key: _kChargeKey);

    // Fuente de puntos: PRIMERO el archivo permanente (sin cap). Si esta vacio
    // (p. ej. recien instalado), se cae al store rapido capado a 200.
    var points = await _readPermanentTrips();
    if (points.isEmpty) {
      final tripRaw = await _wcStorage.read(key: _kTripKey);
      if (tripRaw != null) {
        for (final e in (json.decode(tripRaw) as List)) {
          final m = Map<String, dynamic>.from(e as Map);
          points.add((
            ts: m['ts'] as int,
            km: m['km'] as int,
            soc: (m['soc'] as num).toDouble(),
          ));
        }
      }
    }

    final sessions =
        <({int startTs, int? endTs, double startSoc, double? endSoc})>[];
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

    // Solo sesiones reales: abiertas o cerradas con ganancia >= 1%
    final validSessions = sessions
        .where((s) =>
            s.endTs == null ||
            ((s.endSoc ?? s.startSoc) - s.startSoc) >= 1.0)
        .toList();

    // ---------- ultima carga (texto) ----------
    final closed =
        validSessions.where((s) => s.endTs != null && s.endSoc != null);
    if (closed.isNotEmpty) {
      final s = closed.last;
      final gain = s.endSoc! - s.startSoc;
      final kwh = gain / 100.0 * gBatteryKwh;
      final t = DateTime.fromMillisecondsSinceEpoch(s.endTs!);
      String two(int n) => n.toString().padLeft(2, '0');
      lastCharge =
          'Ultima carga: +${gain.toStringAsFixed(0)}% (~${_d1(kwh)} kWh) '
          '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
    }

    // ---------- cubos de 7 dias ----------
    final today = DateTime.now();
    final days = <String, _DayBar>{};
    final order = <String>[];
    for (var i = 6; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      days[key] = _DayBar(d.day.toString().padLeft(2, '0'));
      order.add(key);
    }
    String keyOf(int ts) {
      final d = DateTime.fromMillisecondsSinceEpoch(ts);
      return '${d.year}-${d.month}-${d.day}';
    }

    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final kmDelta = (curr.km - prev.km).toDouble();
      final socDelta = prev.soc - curr.soc;
      if (kmDelta <= 0 || socDelta <= 0) continue;
      // Cordura: descartar solo tramos fisicamente imposibles.
      final pct = socDelta / kmDelta * 100;
      if (pct < 8.0 || pct > 70.0) continue;
      final bar = days[keyOf(curr.ts)];
      if (bar == null) continue;
      bar.km += kmDelta;
      bar.socDrop += socDelta;
    }

    for (final s in validSessions) {
      days[keyOf(s.startTs)]?.charged = true;
      if (s.endTs != null) {
        final b = days[keyOf(s.endTs!)];
        if (b != null) {
          b.charged = true;
          if (s.endSoc != null) {
            b.chargedKwh += (s.endSoc! - s.startSoc) / 100.0 * gBatteryKwh;
          }
        }
      }
    }
    if (isCharging) days[order.last]?.charged = true;

    final bars = order.map((k) => days[k]!).toList();

    // ---------- media semanal y autonomia real ----------
    final totKm = bars.fold(0.0, (a, b) => a + b.km);
    final totDrop = bars.fold(0.0, (a, b) => a + b.socDrop);
    final double? weekAvg =
        totKm > 0 && totDrop > 0 ? totDrop * gBatteryKwh / totKm : null;
    if (weekAvg != null && socPercent != null && weekAvg >= 12.0) {
      // weekAvg < 12 kWh/100 es inverosimil en este coche (objetivo 15.6):
      // significa datos insuficientes. No se publica una autonomia fantasia.
      // Cap a la autonomia fisica: con pocos datos el consumo medio sale
      // optimista y daria autonomias imposibles (>430). Se limita a 430.
      final r = (socPercent * gBatteryKwh / weekAvg).clamp(0.0, gMaxRangeKm);
      realRange = r.round().toString();
    }

    // Km recorridos desde la ultima RECARGA, detectada como el ultimo salto
    // de SoC hacia arriba entre dos puntos de viaje consecutivos. Mas robusto
    // que depender de chargeSessions (que el sueno del TCU puede no registrar).
    if (points.length >= 2) {
      int rechargeIdx = 0;
      for (var i = 1; i < points.length; i++) {
        // Subida de SoC de >=3% => hubo recarga entre esos dos puntos.
        if (points[i].soc - points[i - 1].soc >= 3) {
          rechargeIdx = i - 1;
        }
      }
      if (rechargeIdx < points.length - 1) {
        final km = points.last.km - points[rechargeIdx].km;
        // Cordura: el ciclo no puede superar la autonomia fisica del coche.
        // Si sale > gMaxRangeKm es que aun no hay suficiente historial
        // para localizar la ultima recarga real (se ve todo el rango
        // disponible en vez de un ciclo). Se avisa en vez de ocultarlo sin
        // explicar, para que quede claro que es falta de datos, no un fallo.
        if (km > 0) {
          cycleKm = km <= gMaxRangeKm ? km.toString() : 'pocos datos';
        }
      }
    }

    try {
      chartText = _buildTextChart(bars, weekAvg, eurKwh);
    } catch (_) {}

    final hasData =
        bars.any((b) => b.kwh100 != null) || bars.any((b) => b.charged);

    if (hasData) {
      final bytes = await _renderChartPng(bars, weekAvg);
      final dir = await getApplicationSupportDirectory();
      // Nombre unico por render: evita que Android reutilice el bitmap viejo.
      try {
        for (final f in dir.listSync()) {
          if (f is File && f.path.contains('/widget_chart')) {
            f.deleteSync();
          }
        }
      } catch (_) {}
      final file = File('${dir.path}/widget_chart_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      chartPath = file.path;
    }
  } catch (_) {
    // Nunca romper el refresco del widget por el grafico.
  }
  return {
    'charging': isCharging ? '1' : '0',
    'lastCharge': lastCharge,
    'chartPath': chartPath,
    'realRange': realRange,
    'chartText': chartText,
    'cycleKm': cycleKm,
  };
}

String _buildTextChart(List<_DayBar> bars, double? weekAvg, double? eurKwh) {
  // Ancho util del widget: unos 22 caracteres. La cabecera de 25 ya se partia
  // en dos lineas en pantalla. Al anadir la columna de euros la barra baja de
  // 8 a 6 bloques para que la fila se quede en 20 y no se rompa. Sin precio
  // configurado no cambia nada respecto a antes.
  // Fuera las barras por dia.
  //
  // Costaban 7 caracteres de los ~22 que caben y solo daban comparacion
  // relativa, que las cifras alineadas ya dan igual de bien. Con ese hueco
  // entran los KILOMETROS, que era el dato que faltaba y sin el la tabla
  // parecia contradecirse: un dia a 14,2 kWh/100 costaba 0,17 y otro a 14,8
  // costaba 1,10. No es el ritmo, son los kilometros (9 frente a 57).
  //
  // El kWh/100 mide COMO conduces; los km, CUANTO usas el coche; el euro es
  // consecuencia de los dos. El '>' sigue marcando los dias sobre objetivo.
  final conEuro = eurKwh != null;
  final sb = StringBuffer();
  // Ancho util medido en pantalla: 22 caracteres con monospace a 13sp. El
  // titulo anterior gastaba 25 y se partia en dos lineas.
  sb.writeln('Consumo dia  obj ${_d1(kTargetKwh100)}');
  // La cabecera tiene que cuadrar EXACTAMENTE con el reparto de las filas:
  //   dia(2) espacio(1) kWh(5) marca(1) km(4) euro(6) = 19 caracteres.
  sb.writeln('dia' +
      'kWh'.padLeft(5) +
      ' ' +
      'km'.padLeft(4) +
      (conEuro ? '\u20AC'.padLeft(6) : ''));
  for (final b in bars) {
    final v = b.kwh100;
    final bolt = b.charged ? ' \u26A1' : '';
    final km = b.km <= 0 ? '' : b.km.toStringAsFixed(0);
    if (v == null) {
      sb.writeln('${b.label} ${'--'.padLeft(5)} ${km.padLeft(4)}$bolt');
      continue;
    }
    final over = v > kTargetKwh100 ? '>' : ' ';
    // Euros del dia: caida de SoC pasada a kWh por el precio. NO se deriva del
    // kWh/100, que ya viene dividido por kilometros y daria euros por 100 km.
    final eur = conEuro
        ? (b.socDrop / 100.0 * gBatteryKwh * eurKwh!)
            .toStringAsFixed(2)
            .replaceAll('.', ',')
            .padLeft(6)
        : '';
    sb.writeln(
        '${b.label} ${_d1(v).padLeft(5)}$over${km.padLeft(4)}$eur$bolt');
  }
  if (weekAvg != null && weekAvg >= 12.0) {
    final estFull =
        (gBatteryKwh / weekAvg * 100).round().clamp(0, gMaxRangeKm.round());
    sb.writeln('Media 7d ${_d1(weekAvg)}  ~$estFull km');
  }
  return sb.toString().trimRight();
}

Future<List<int>> _renderChartPng(List<_DayBar> bars, double? weekAvg) async {
  // Estilo eConsumo: barras anchas, valor kWh/100 encima de cada una,
  // cabecera con media/objetivo. Colores azul/verde (no cian).
  const w = 680.0, h = 470.0;
  const leftPad = 24.0, rightPad = 24.0, topPad = 118.0, bottomPad = 96.0;
  final plotW = w - leftPad - rightPad;
  final plotH = h - topPad - bottomPad;
  final plotBottom = topPad + plotH;
  final slotW = plotW / bars.length;
  final barW = slotW * 0.72; // barras anchas, como eConsumo

  final values = bars.map((b) => b.kwh100 ?? 0.0).toList();
  final maxVal = math.max(values.fold(0.0, math.max), kTargetKwh100) * 1.30;
  double yOf(double v) => topPad + plotH * (1 - v / maxVal);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  TextPainter tpOf(String text, double size, Color color,
      {FontWeight weight = FontWeight.w600}) {
    return TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  // Panel redondeado
  final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, w - 8, h - 8), const Radius.circular(30));
  canvas.drawRRect(panel, Paint()..color = const Color(0x66FFFFFF));

  // Cabecera estilo eConsumo: titulo grande + subtitulo con media
  final title = tpOf('Consumo diario', 30, _cBlue, weight: FontWeight.w800);
  title.paint(canvas, const Offset(leftPad, 18));
  final sub =
      tpOf('objetivo ${_d1(kTargetKwh100)} kWh/100 = ' + gMaxRangeKm.round().toString() + ' km', 22, _cBlue);
  sub.paint(canvas, const Offset(leftPad, 58));
  if (weekAvg != null && weekAvg >= 12.0) {
    final estFull = (gBatteryKwh / weekAvg * 100).round();
    final ok = weekAvg <= kTargetKwh100;
    final avg = tpOf('Media 7d: ${_d1(weekAvg)}  ·  ~$estFull km/carga', 24,
        ok ? _cGood : _cOver,
        weight: FontWeight.w800);
    avg.paint(canvas, Offset(w - rightPad - avg.width, 20));
  }

  // Eje base
  canvas.drawLine(
      Offset(leftPad, plotBottom),
      Offset(w - rightPad, plotBottom),
      Paint()
        ..color = _cBlue.withOpacity(0.28)
        ..strokeWidth = 3);

  // Barras anchas con valor encima (formato eConsumo)
  for (var i = 0; i < bars.length; i++) {
    final b = bars[i];
    final cx = leftPad + slotW * i + slotW / 2;
    final v = b.kwh100;
    if (v != null) {
      final over = v > kTargetKwh100;
      final color = over ? _cOver : _cGood;
      final top = yOf(v);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, plotBottom),
        topLeft: const Radius.circular(9),
        topRight: const Radius.circular(9),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      final lbl = tpOf(_d1(v), 30, _cBlue, weight: FontWeight.w800);
      lbl.paint(canvas, Offset(cx - lbl.width / 2, top - 42));
    }
    // Dia del mes (debajo del eje, como eConsumo)
    final day = tpOf(b.label, 28, _cBlue, weight: FontWeight.w700);
    day.paint(canvas, Offset(cx - day.width / 2, plotBottom + 12));
    // Rayo + kWh cargados
    if (b.charged) {
      if (b.chargedKwh > 0.05) {
        final kw =
            tpOf('+${_d1(b.chargedKwh)}', 20, _cGood, weight: FontWeight.w800);
        final total = 24 + 6 + kw.width;
        final startX = cx - total / 2;
        _drawBolt(canvas, Offset(startX + 12, plotBottom + 60), 12, _cGood);
        kw.paint(canvas, Offset(startX + 30, plotBottom + 48));
      } else {
        _drawBolt(canvas, Offset(cx, plotBottom + 60), 12, _cGood);
      }
    }
  }

  // Linea objetivo discontinua (430 km)
  final yT = yOf(kTargetKwh100);
  final dashPaint = Paint()
    ..color = _cLine
    ..strokeWidth = 5;
  double x = leftPad;
  while (x < w - rightPad) {
    canvas.drawLine(
        Offset(x, yT), Offset(math.min(x + 16, w - rightPad), yT), dashPaint);
    x += 26;
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void _drawBolt(Canvas canvas, Offset center, double r, Color color) {
  final p = Path()
    ..moveTo(center.dx + r * 0.25, center.dy - r)
    ..lineTo(center.dx - r * 0.55, center.dy + r * 0.15)
    ..lineTo(center.dx - r * 0.05, center.dy + r * 0.15)
    ..lineTo(center.dx - r * 0.25, center.dy + r)
    ..lineTo(center.dx + r * 0.55, center.dy - r * 0.15)
    ..lineTo(center.dx + r * 0.05, center.dy - r * 0.15)
    ..close();
  canvas.drawPath(p, Paint()..color = color);
}
