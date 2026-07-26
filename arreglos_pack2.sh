#!/bin/bash
# ============================================================================
# LMB10 - arreglos_pack2.sh
#  1) "Cargando" falso: isCharging pasaba con chargeState != 0, que tambien
#     ocurre con REGENERACION al conducir y con carga TERMINADA enchufado.
#     Nuevo criterio en el motor: chargeState activo Y enchufado Y carga no
#     completada (senal 3736). Arregla widget, etiqueta del dashboard y
#     remata de raiz las sesiones fantasma del historial.
#  2) Grafico del widget v2: sin solapes (leyenda arriba), barras verdes si
#     <= objetivo y naranjas si lo superan, linea roja 15,6 = 430 km, media
#     semanal con km/carga estimados, kWh cargados junto al rayo, eje base.
#  3) Nueva linea en el widget: autonomia real estimada segun TU consumo
#     ("348 km · real ~358 km").
# Ejecutar desde la raiz: bash arreglos_pack2.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

mkdir -p backups_widget
cp lib/leapmotor_engine.dart backups_widget/leapmotor_engine.dart.bak_fix2
cp lib/main.dart backups_widget/main.dart.bak_fix2
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_fix2
KT=android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt
cp "$KT" backups_widget/BatteryWidgetProvider.kt.bak_fix2
echo "Backups .bak_fix2 en backups_widget/"

# ---------------------------------------------------------------------------
# 1) Parches: motor (isCharging real) + llamada del widget (soc para
#    autonomia real)
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys

def patch(path, jobs):
    src = open(path, encoding='utf-8').read()
    for label, anchor, repl in jobs:
        n = src.count(anchor)
        if n != 1:
            print(f"ERROR '{label}': ancla {n} veces (esperada 1). {path} sin tocar.")
            sys.exit(1)
        src = src.replace(anchor, repl)
        print(f"OK  {label}")
    open(path, 'w', encoding='utf-8').write(src)

patch('lib/leapmotor_engine.dart', [
 ('isCharging real (enchufado + no completada)',
  "  bool get isCharging => (chargeState ?? 0) != 0;",
  """  /// Cargando de verdad: chargeState activo Y enchufado Y carga no
  /// completada. chargeState != 0 tambien se da con la regeneracion al
  /// conducir y con la carga terminada: causaba falsos "Cargando" y
  /// sesiones fantasma en el historial.
  bool get isCharging =>
      (chargeState ?? 0) != 0 &&
      isPluggedIn &&
      (chargeCompleted != true);"""),
])

patch('lib/main.dart', [
 ('pasar SOC al grafico del widget',
  "    final extras = await buildWidgetExtras(isCharging: s.isCharging);",
  "    final extras = await buildWidgetExtras(isCharging: s.isCharging, socPercent: s.preciseSoc ?? s.soc?.toDouble());"),
])
print('OK  parches aplicados')
PYEOF

# ---------------------------------------------------------------------------
# 2) widget_chart.dart v2 (regenerado completo)
# ---------------------------------------------------------------------------
cat > lib/widget_chart.dart << 'EOF'
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

const double kB10BatteryKwh = 67.1;
const double kB10MaxRangeKm = 430.0;
final double kTargetKwh100 = kB10BatteryKwh / kB10MaxRangeKm * 100.0; // 15.60

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
  double? get kwh100 =>
      km > 0 && socDrop > 0 ? socDrop * kB10BatteryKwh / km : null;
}

String _d1(num v) => v.toStringAsFixed(1).replaceAll('.', ',');

Future<Map<String, String>> buildWidgetExtras(
    {required bool isCharging, double? socPercent}) async {
  String lastCharge = '';
  String chartPath = '';
  String realRange = '';
  try {
    // ---------- datos locales ----------
    final tripRaw = await _wcStorage.read(key: _kTripKey);
    final chargeRaw = await _wcStorage.read(key: _kChargeKey);

    final points = <({int ts, int km, double soc})>[];
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
      final kwh = gain / 100.0 * kB10BatteryKwh;
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
            b.chargedKwh += (s.endSoc! - s.startSoc) / 100.0 * kB10BatteryKwh;
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
        totKm > 0 && totDrop > 0 ? totDrop * kB10BatteryKwh / totKm : null;
    if (weekAvg != null && socPercent != null) {
      final r = (socPercent * kB10BatteryKwh / weekAvg).clamp(0.0, 999.0);
      realRange = r.round().toString();
    }

    final hasData =
        bars.any((b) => b.kwh100 != null) || bars.any((b) => b.charged);

    if (hasData) {
      final bytes = await _renderChartPng(bars, weekAvg);
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/widget_chart.png');
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
  };
}

Future<List<int>> _renderChartPng(List<_DayBar> bars, double? weekAvg) async {
  const w = 660.0, h = 344.0;
  const leftPad = 10.0, rightPad = 10.0, topPad = 62.0, bottomPad = 62.0;
  final plotW = w - leftPad - rightPad;
  final plotH = h - topPad - bottomPad;
  final plotBottom = topPad + plotH;
  final slotW = plotW / bars.length;
  final barW = slotW * 0.52;

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

  // Leyenda (izquierda) y media semanal (derecha), fila superior sin solapes
  final legend = tpOf(
      'kWh/100km - objetivo ${_d1(kTargetKwh100)} = 430 km', 17, _cBlue);
  legend.paint(canvas, const Offset(leftPad, 8));
  if (weekAvg != null) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    final ok = weekAvg <= kTargetKwh100;
    final sum = tpOf('Media 7d: ${_d1(weekAvg)} = ~$estFull km/carga', 17,
        ok ? _cGood : _cOver,
        weight: FontWeight.w700);
    sum.paint(canvas, Offset(w - rightPad - sum.width, 32));
  }

  // Eje base
  canvas.drawLine(
      Offset(leftPad, plotBottom),
      Offset(w - rightPad, plotBottom),
      Paint()
        ..color = _cBlue.withOpacity(0.25)
        ..strokeWidth = 2);

  // Barras
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
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      final lbl = tpOf(_d1(v), 19, color, weight: FontWeight.w700);
      lbl.paint(canvas, Offset(cx - lbl.width / 2, top - 26));
    }
    // Dia del mes
    final day = tpOf(b.label, 20, _cBlue);
    day.paint(canvas, Offset(cx - day.width / 2, plotBottom + 6));
    // Rayo (+ kWh cargados si se conocen)
    if (b.charged) {
      if (b.chargedKwh > 0.05) {
        final kw = tpOf('+${_d1(b.chargedKwh)}', 15, _cGood,
            weight: FontWeight.w700);
        final total = 20 + 4 + kw.width;
        final startX = cx - total / 2;
        _drawBolt(canvas, Offset(startX + 10, plotBottom + 44), 10, _cGood);
        kw.paint(canvas, Offset(startX + 24, plotBottom + 36));
      } else {
        _drawBolt(canvas, Offset(cx, plotBottom + 44), 10, _cGood);
      }
    }
  }

  // Linea objetivo discontinua (sin etiqueta encima: ya esta en la leyenda)
  final yT = yOf(kTargetKwh100);
  final dashPaint = Paint()
    ..color = _cLine
    ..strokeWidth = 3.5;
  double x = leftPad;
  while (x < w - rightPad) {
    canvas.drawLine(
        Offset(x, yT), Offset(math.min(x + 12, w - rightPad), yT), dashPaint);
    x += 20;
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
EOF
echo "OK  lib/widget_chart.dart v2"

# ---------------------------------------------------------------------------
# 3) Provider: linea de autonomia real ("348 km · real ~358 km")
# ---------------------------------------------------------------------------
cat > "$KT" << 'EOF'
package com.txurtxil.lpb10
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class BatteryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        render(context, appWidgetManager, appWidgetId)
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.battery_widget)

        val minH = try {
            mgr.getAppWidgetOptions(widgetId).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        } catch (_: Exception) { 180 }
        val tiny = minH < 90
        val large = minH >= 170

        val soc = prefs.getString("soc", null)
        val range = prefs.getString("range", null)
        val realRange = prefs.getString("realRange", null)
        val locked = prefs.getString("locked", null)
        val updated = prefs.getString("updated", null)
        val charging = prefs.getString("charging", null)
        val lastCharge = prefs.getString("lastCharge", null)
        val chartPath = prefs.getString("chartPath", null)

        views.setTextViewText(R.id.widget_soc, if (soc != null) "$soc%" else "--%")
        val rangeText = when {
            range != null && !realRange.isNullOrEmpty() -> "$range km · real ~$realRange km"
            range != null -> "$range km autonomia"
            else -> "-- km autonomia"
        }
        views.setTextViewText(R.id.widget_range, rangeText)
        views.setTextViewText(R.id.widget_lock, when (locked) {
            "1" -> "Cerrado"
            "0" -> "Abierto"
            else -> "Estado desconocido"
        })
        views.setTextViewText(R.id.widget_updated, updated ?: "")

        val chargeText = when {
            charging == "1" -> "\u26A1 Cargando..."
            !lastCharge.isNullOrEmpty() -> "\u26A1 " + lastCharge
            else -> null
        }

        views.setViewVisibility(R.id.widget_lock, if (tiny) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_updated, if (tiny) View.GONE else View.VISIBLE)
        if (!tiny && chargeText != null) {
            views.setTextViewText(R.id.widget_charge, chargeText)
            views.setViewVisibility(R.id.widget_charge, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_charge, View.GONE)
        }

        var chartShown = false
        if (large && !chartPath.isNullOrEmpty()) {
            try {
                val bmp = BitmapFactory.decodeFile(chartPath)
                if (bmp != null) {
                    views.setImageViewBitmap(R.id.widget_chart, bmp)
                    views.setViewVisibility(R.id.widget_chart, View.VISIBLE)
                    chartShown = true
                }
            } catch (_: Exception) { }
        }
        if (!chartShown) views.setViewVisibility(R.id.widget_chart, View.GONE)

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
        val refreshIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent)
        try { mgr.updateAppWidget(widgetId, views) } catch (_: Exception) { }
    }
}
EOF
echo "OK  $KT"

cat << 'DONE'
============================================================
PACK 2 APLICADO. Compila:
  flutter build apk --release
============================================================
DONE
