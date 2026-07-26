#!/bin/bash
# ============================================================================
# LMB10 - widget_chart_upgrade.sh
# Mejora del widget de pantalla de inicio:
#   - Grafico de barras: consumo diario (kWh/100 km) de los ultimos 7 dias,
#     calculado desde TripPointStore (odometro + SOC).
#   - Linea de referencia cruzando la semana a 15,6 kWh/100 km
#     (= 67,1 kWh / 430 km): por debajo = camino de autonomia maxima.
#   - Dias con carga marcados con un rayo; linea "Ultima carga: +X% ..." y
#     estado "Cargando" en vivo -> las cargas SIEMPRE visibles en el widget.
#
# Ejecutar desde la raiz del proyecto: bash widget_chart_upgrade.sh
# Heredocs con 'EOF' entre comillas: $ de Dart/Kotlin intacto, sin sed.
# ============================================================================
set -e

[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

KT=android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt
LAYOUT=android/app/src/main/res/layout/battery_widget.xml
INFO=android/app/src/main/res/xml/battery_widget_info.xml
[ -f "$KT" ] || { echo "ERROR: no existe $KT"; exit 1; }

cp lib/main.dart lib/main.dart.bak_widget
cp "$KT" "$KT.bak_widget"
cp "$LAYOUT" "$LAYOUT.bak_widget"
cp "$INFO" "$INFO.bak_widget"
echo "Backups .bak_widget creados"

# ----------------------------------------------------------------------------
# 1) lib/widget_chart.dart - calculo diario + render PNG (Canvas dart:ui)
#    Autocontenido: lee lm_trip_points_v1 y lm_charge_history_v1 directamente,
#    sin importar main.dart. Funciona tambien desde WorkManager.
# ----------------------------------------------------------------------------
cat > lib/widget_chart.dart << 'EOF'
// widget_chart.dart - Grafico de consumo diario para el widget de inicio.
//
// Barras: kWh/100 km por dia (ultimos 7 dias), desde los puntos de viaje
//   (odometro + SOC): kWh/100km = caidaSOC% * 67.1 / km.
// Linea objetivo: 15,6 kWh/100 km = 67,1 kWh / 430 km (autonomia maxima B10).
// Rayo bajo el dia: hubo carga ese dia (ChargeHistoryStore).
//
// Devuelve un mapa de claves para HomeWidget:
//   'charging'  -> '1'/'0'
//   'lastCharge'-> "Ultima carga: +38% (~25,5 kWh) 08/07 06:42" o ''
//   'chartPath' -> ruta absoluta del PNG o ''

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

class _DayBar {
  final String label; // dia del mes '03'
  double km = 0;
  double socDrop = 0;
  bool charged = false;
  _DayBar(this.label);
  double? get kwh100 =>
      km > 0 && socDrop > 0 ? socDrop * kB10BatteryKwh / km : null;
}

Future<Map<String, String>> buildWidgetExtras({required bool isCharging}) async {
  String lastCharge = '';
  String chartPath = '';
  try {
    // ---------- cargar datos locales ----------
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

    // ---------- ultima carga (texto) ----------
    final closed = sessions.where((s) => s.endTs != null && s.endSoc != null);
    if (closed.isNotEmpty) {
      final s = closed.last;
      final gain = s.endSoc! - s.startSoc;
      if (gain > 0.5) {
        final kwh = gain / 100.0 * kB10BatteryKwh;
        final t = DateTime.fromMillisecondsSinceEpoch(s.endTs!);
        String two(int n) => n.toString().padLeft(2, '0');
        lastCharge =
            'Ultima carga: +${gain.toStringAsFixed(0)}% (~${kwh.toStringAsFixed(1).replaceAll('.', ',')} kWh) '
            '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
      }
    }

    // ---------- barras de los ultimos 7 dias ----------
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
    for (final s in sessions) {
      days[keyOf(s.startTs)]?.charged = true;
      if (s.endTs != null) days[keyOf(s.endTs!)]?.charged = true;
    }
    if (isCharging) days[order.last]?.charged = true;

    final bars = order.map((k) => days[k]!).toList();
    final hasData =
        bars.any((b) => b.kwh100 != null) || bars.any((b) => b.charged);

    // ---------- render PNG ----------
    if (hasData) {
      final bytes = await _renderChartPng(bars);
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
  };
}

Future<List<int>> _renderChartPng(List<_DayBar> bars) async {
  const w = 660.0, h = 330.0;
  const leftPad = 10.0, rightPad = 10.0, topPad = 34.0, bottomPad = 56.0;
  const barColor = Color(0xFF0D3B66); // azul del widget
  const lineColor = Color(0xFFE63946); // rojo objetivo
  const boltColor = Color(0xFF2A9D8F); // verde carga
  final plotW = w - leftPad - rightPad;
  final plotH = h - topPad - bottomPad;
  final slotW = plotW / bars.length;
  final barW = slotW * 0.52;

  final values = bars.map((b) => b.kwh100 ?? 0.0).toList();
  final maxVal = math.max(values.fold(0.0, math.max), kTargetKwh100) * 1.28;

  double yOf(double v) => topPad + plotH * (1 - v / maxVal);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

  void drawText(String text, double cx, double y,
      {double size = 20,
      Color color = barColor,
      FontWeight weight = FontWeight.w600,
      bool centered = true}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(fontSize: size, color: color, fontWeight: weight)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centered ? cx - tp.width / 2 : cx, y));
  }

  // Barras + etiquetas
  final barPaint = Paint()..color = barColor;
  for (var i = 0; i < bars.length; i++) {
    final b = bars[i];
    final cx = leftPad + slotW * i + slotW / 2;
    final v = b.kwh100;
    if (v != null) {
      final top = yOf(v);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, topPad + plotH),
        const Radius.circular(7),
      );
      canvas.drawRRect(rect, barPaint);
      drawText(v.toStringAsFixed(1).replaceAll('.', ','), cx, top - 26,
          size: 19);
    }
    // Dia del mes
    drawText(b.label, cx, topPad + plotH + 6, size: 20);
    // Rayo si hubo carga ese dia
    if (b.charged) {
      _drawBolt(canvas, Offset(cx, topPad + plotH + 40), 11, boltColor);
    }
  }

  // Linea objetivo discontinua a 15,6 kWh/100km
  final yT = yOf(kTargetKwh100);
  final dashPaint = Paint()
    ..color = lineColor
    ..strokeWidth = 3.5;
  double x = leftPad;
  while (x < w - rightPad) {
    canvas.drawLine(
        Offset(x, yT), Offset(math.min(x + 12, w - rightPad), yT), dashPaint);
    x += 20;
  }
  // Etiqueta de la linea objetivo, alineada a la derecha
  final tp = TextPainter(
    text: TextSpan(
        text:
            '${kTargetKwh100.toStringAsFixed(1).replaceAll('.', ',')} - 430 km',
        style: const TextStyle(
            fontSize: 18, color: lineColor, fontWeight: FontWeight.w700)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(w - rightPad - tp.width, yT - 26));

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
echo "OK  lib/widget_chart.dart"

# ----------------------------------------------------------------------------
# 2) Parche de main.dart: import + _pushToHomeWidget ampliado
# ----------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
path = 'lib/main.dart'
src = open(path, encoding='utf-8').read()

def apply(anchor, replacement, label):
    global src
    n = src.count(anchor)
    if n != 1:
        print(f"ERROR parche '{label}': ancla {n} veces (esperada 1). Sin cambios.")
        sys.exit(1)
    src = src.replace(anchor, replacement)
    print(f"OK  parche '{label}'")

apply("import 'settings_screen.dart';",
      "import 'settings_screen.dart';\nimport 'widget_chart.dart';",
      'import widget_chart')

old_push = """Future<void> _pushToHomeWidget(VehicleStatus s) async {
  final soc = (s.preciseSoc ?? s.soc?.toDouble())?.toStringAsFixed(1);
  await HomeWidget.saveWidgetData<String>('soc', soc ?? '--');
  await HomeWidget.saveWidgetData<String>('range', '${s.liveRemainingRange ?? '--'}');
  await HomeWidget.saveWidgetData<String>('locked', s.isLocked ? '1' : '0');
  await HomeWidget.saveWidgetData<String>('updated', 'Actualizado ${TimeOfDay.now().format24Hour()}');
  await HomeWidget.updateWidget(androidName: 'BatteryWidgetProvider');
}"""

new_push = """Future<void> _pushToHomeWidget(VehicleStatus s) async {
  final soc = (s.preciseSoc ?? s.soc?.toDouble())?.toStringAsFixed(1);
  await HomeWidget.saveWidgetData<String>('soc', soc ?? '--');
  await HomeWidget.saveWidgetData<String>('range', '${s.liveRemainingRange ?? '--'}');
  await HomeWidget.saveWidgetData<String>('locked', s.isLocked ? '1' : '0');
  await HomeWidget.saveWidgetData<String>('updated', 'Actualizado ${TimeOfDay.now().format24Hour()}');
  // Grafico de consumo diario + info de carga (widget_chart.dart)
  try {
    final extras = await buildWidgetExtras(isCharging: s.isCharging);
    for (final entry in extras.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
  } catch (_) {
    // El grafico nunca debe romper el refresco del widget
  }
  await HomeWidget.updateWidget(androidName: 'BatteryWidgetProvider');
}"""

apply(old_push, new_push, '_pushToHomeWidget')

open(path, 'w', encoding='utf-8').write(src)
print('OK  lib/main.dart parcheado')
PYEOF

# ----------------------------------------------------------------------------
# 3) Provider Kotlin: nuevas claves charging/lastCharge/chartPath
# ----------------------------------------------------------------------------
cat > "$KT" << 'EOF'
package com.txurtxil.lpb10
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class BatteryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.battery_widget)
            val soc = prefs.getString("soc", null)
            val range = prefs.getString("range", null)
            val locked = prefs.getString("locked", null)
            val updated = prefs.getString("updated", null)
            val charging = prefs.getString("charging", null)
            val lastCharge = prefs.getString("lastCharge", null)
            val chartPath = prefs.getString("chartPath", null)

            views.setTextViewText(R.id.widget_soc, if (soc != null) "$soc%" else "--%")
            views.setTextViewText(R.id.widget_range, if (range != null) "$range km autonomia" else "-- km autonomia")
            views.setTextViewText(R.id.widget_lock, when (locked) {
                "1" -> "Cerrado"
                "0" -> "Abierto"
                else -> "Estado desconocido"
            })
            views.setTextViewText(R.id.widget_updated, updated ?: "")

            // Linea de carga: en vivo si esta cargando; si no, la ultima carga.
            val chargeText = when {
                charging == "1" -> "\u26A1 Cargando..."
                !lastCharge.isNullOrEmpty() -> "\u26A1 " + lastCharge
                else -> null
            }
            if (chargeText != null) {
                views.setTextViewText(R.id.widget_charge, chargeText)
                views.setViewVisibility(R.id.widget_charge, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_charge, View.GONE)
            }

            // Grafico de consumo diario (PNG generado por la app)
            var chartShown = false
            if (!chartPath.isNullOrEmpty()) {
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
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
EOF
echo "OK  $KT"

# ----------------------------------------------------------------------------
# 4) Layout: nueva linea de carga + ImageView del grafico
# ----------------------------------------------------------------------------
cat > "$LAYOUT" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:background="#BFE0FA"
    android:padding="12dp"
    android:id="@+id/widget_root">
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal">
        <TextView
            android:id="@+id/widget_title"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Leapmotor B10"
            android:textColor="#0D3B66"
            android:textStyle="bold"
            android:textSize="13sp" />
        <ImageButton
            android:id="@+id/widget_refresh"
            android:layout_width="28dp"
            android:layout_height="28dp"
            android:background="@android:color/transparent"
            android:src="@android:drawable/ic_popup_sync"
            android:contentDescription="Actualizar" />
    </LinearLayout>
    <TextView
        android:id="@+id/widget_soc"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="--%"
        android:textColor="#0D3B66"
        android:textStyle="bold"
        android:textSize="26sp"
        android:layout_marginTop="4dp" />
    <TextView
        android:id="@+id/widget_range"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="-- km autonomia"
        android:textColor="#0D3B66"
        android:textSize="12sp" />
    <TextView
        android:id="@+id/widget_lock"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Estado desconocido"
        android:textColor="#0D3B66"
        android:textSize="12sp"
        android:layout_marginTop="2dp" />
    <TextView
        android:id="@+id/widget_charge"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text=""
        android:visibility="gone"
        android:textColor="#1B7A4B"
        android:textStyle="bold"
        android:textSize="12sp"
        android:layout_marginTop="2dp" />
    <ImageView
        android:id="@+id/widget_chart"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:layout_marginTop="6dp"
        android:scaleType="fitCenter"
        android:visibility="gone"
        android:contentDescription="Consumo diario" />
    <TextView
        android:id="@+id/widget_updated"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text=""
        android:textColor="#0D3B66"
        android:textSize="10sp"
        android:layout_marginTop="4dp" />
</LinearLayout>
EOF
echo "OK  $LAYOUT"

# ----------------------------------------------------------------------------
# 5) Info del widget: altura minima mayor para que quepa el grafico
# ----------------------------------------------------------------------------
cat > "$INFO" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="180dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/battery_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
EOF
echo "OK  $INFO"

cat << 'DONE'
============================================================
WIDGET AMPLIADO. Compila e instala:
  flutter build apk --release
NOTAS:
 - Tras instalar, QUITA y VUELVE A PONER el widget en el
   escritorio (el tamano minimo ha cambiado a 180dp de alto)
   y agrandalo verticalmente para ver bien las barras.
 - Las barras usan los puntos de viaje ya guardados
   (lm_trip_points_v1): los dias sin conduccion registrada
   salen vacios; se iran llenando con el uso normal.
 - Formula: kWh/100km = caidaSOC% x 67,1 / km del dia.
   Linea roja = 15,6 kWh/100km (67,1 kWh / 430 km).
 - Rayo verde bajo el dia = hubo carga (y la de anoche ya
   aparece via lm_charge_history_v1 + linea "Ultima carga").
 - Si algo fallara: restaura los .bak_widget
============================================================
DONE
