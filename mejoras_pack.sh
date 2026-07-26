#!/bin/bash
# ============================================================================
# LMB10 - mejoras_pack.sh
#  1) ARREGLO historial de cargas: chargeState parpadea (regeneracion,
#     enchufado sin cargar...) y creaba sesiones fantasma "85% -> 85%".
#     Ahora: sesiones con ganancia < 1% se descartan y las ya guardadas
#     se filtran automaticamente.
#  2) HISTORICO PERMANENTE: cada punto de viaje y cada carga real se
#     archivan en JSONL sin limite (los stores actuales capan a 200/25).
#  3) EXPORTAR: boton en el Dashboard -> comparte backup JSON + 2 CSV
#     (viajes y cargas) via hoja de compartir Android (share_plus).
#  4) WIDGET "GASEOSO": redimensionable libre desde 110x48dp; se adapta
#     solo al tamano (pequeno: SOC+autonomia / medio: + estado y carga /
#     grande: + grafico de consumo).
# Ejecutar desde la raiz: bash mejoras_pack.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_pack
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_pack
KT=android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt
INFO=android/app/src/main/res/xml/battery_widget_info.xml
cp "$KT" backups_widget/BatteryWidgetProvider.kt.bak_pack
cp "$INFO" backups_widget/battery_widget_info.xml.bak_pack
echo "Backups en backups_widget/"

# ---------------------------------------------------------------------------
# Dependencia share_plus (hoja de compartir)
# ---------------------------------------------------------------------------
if command -v flutter >/dev/null; then
  grep -q "share_plus" pubspec.yaml || flutter pub add share_plus
else
  echo "AVISO: ejecuta luego 'flutter pub add share_plus'"
fi

# ---------------------------------------------------------------------------
# 1) lib/history_archive.dart - archivo permanente + exportacion
# ---------------------------------------------------------------------------
cat > lib/history_archive.dart << 'EOF'
// history_archive.dart - Historico permanente (JSONL) y exportacion.
// Los stores de la app capan a 200 puntos / 25 sesiones; este archivo
// guarda TODO sin limite en Documents/lmb10_history/ y permite exportar
// backup JSON + CSVs (separador ';', decimales con coma para Excel ES).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
EOF
echo "OK  lib/history_archive.dart"

# ---------------------------------------------------------------------------
# 2) Parches a main.dart y widget_chart.dart (anclas exactas)
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

# ---------------- main.dart ----------------
patch('lib/main.dart', [
 ('import history_archive',
  "import 'widget_chart.dart';",
  "import 'widget_chart.dart';\nimport 'history_archive.dart';"),

 ('archivo en addPoint',
  """  static Future<void> addPoint(int totalMileage, double soc) async {
    final points = await load();
    points.add(TripPoint(ts: DateTime.now().millisecondsSinceEpoch, totalMileage: totalMileage, soc: soc));""",
  """  static Future<void> addPoint(int totalMileage, double soc) async {
    final points = await load();
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    points.add(TripPoint(ts: nowTs, totalMileage: totalMileage, soc: soc));
    await HistoryArchive.appendTrip(nowTs, totalMileage, soc);"""),

 ('filtro sesiones fantasma en load()',
  "      return (json.decode(raw) as List).map((e) => ChargeSession.fromMap(Map<String, dynamic>.from(e as Map))).toList();",
  """      final all = (json.decode(raw) as List).map((e) => ChargeSession.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      // chargeState parpadea (regeneracion, enchufado sin cargar...):
      // se ocultan las sesiones cerradas con ganancia < 1%.
      return all.where((s) => s.endTs == null || ((s.endSoc ?? s.startSoc) - s.startSoc) >= 1.0).toList();"""),

 ('descarte + archivo en endSession',
  """  static Future<void> endSession(double soc) async {
    final sessions = await load();
    if (sessions.isEmpty || sessions.last.endTs != null) return;
    sessions.last.endTs = DateTime.now().millisecondsSinceEpoch;
    sessions.last.endSoc = soc;
    await _saveAll(sessions);
  }""",
  """  static Future<void> endSession(double soc) async {
    final sessions = await load();
    if (sessions.isEmpty || sessions.last.endTs != null) return;
    final s = sessions.last;
    if (soc - s.startSoc < 1.0) {
      // Parpadeo de chargeState: no es una carga real, se descarta.
      sessions.removeLast();
      await _saveAll(sessions);
      return;
    }
    s.endTs = DateTime.now().millisecondsSinceEpoch;
    s.endSoc = soc;
    await _saveAll(sessions);
    await HistoryArchive.appendCharge(s.startTs, s.endTs!, s.startSoc, soc);
  }"""),

 ('boton exportar en Dashboard',
  """                  OutlinedButton.icon(
                    icon: const Icon(Icons.security, size: 18),""",
  """                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Exportar historico' : 'Export history'),
                    onPressed: () async {
                      final ok = await exportHistoryAndShare();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Backup generado' : 'No se pudo exportar')),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.security, size: 18),"""),
])

# ---------------- widget_chart.dart ----------------
patch('lib/widget_chart.dart', [
 ('filtrar sesiones validas (ultima carga)',
  "    final closed = sessions.where((s) => s.endTs != null && s.endSoc != null);",
  """    final validSessions = sessions
        .where((s) =>
            s.endTs == null ||
            ((s.endSoc ?? s.startSoc) - s.startSoc) >= 1.0)
        .toList();
    final closed =
        validSessions.where((s) => s.endTs != null && s.endSoc != null);"""),

 ('filtrar sesiones validas (rayos)',
  "    for (final s in sessions) {",
  "    for (final s in validSessions) {"),
])
print('OK  parches aplicados')
PYEOF

# ---------------------------------------------------------------------------
# 3) Provider Kotlin adaptativo al tamano (widget "gaseoso")
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

    // Se llama al redimensionar con el dedo: el widget se adapta al vuelo.
    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        render(context, appWidgetManager, appWidgetId)
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.battery_widget)

        val minH = try {
            mgr.getAppWidgetOptions(widgetId).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        } catch (_: Exception) { 180 }
        val tiny = minH < 90      // solo titulo + SOC + autonomia
        val large = minH >= 170   // todo + grafico

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

        val chargeText = when {
            charging == "1" -> "\u26A1 Cargando..."
            !lastCharge.isNullOrEmpty() -> "\u26A1 " + lastCharge
            else -> null
        }

        // Visibilidad segun tamano
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
        appWidgetManager_updateSafe(mgr, widgetId, views)
    }

    private fun appWidgetManager_updateSafe(mgr: AppWidgetManager, id: Int, views: RemoteViews) {
        try { mgr.updateAppWidget(id, views) } catch (_: Exception) { }
    }
}
EOF
echo "OK  $KT"

# ---------------------------------------------------------------------------
# 4) Info del widget: redimension libre desde muy pequeno
# ---------------------------------------------------------------------------
cat > "$INFO" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp"
    android:minHeight="180dp"
    android:minResizeWidth="110dp"
    android:minResizeHeight="48dp"
    android:targetCellWidth="3"
    android:targetCellHeight="3"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/battery_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen" />
EOF
echo "OK  $INFO"

cat << 'DONE'
============================================================
PACK APLICADO. Compila:
  flutter build apk --release
============================================================
DONE
