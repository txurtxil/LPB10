#!/bin/bash
# ============================================================================
# LMB10 - pack_ticket.sh  —  Ticket termico de eficiencia (RawBT / DPP-250)
#
#  Genera un ticket monoespaciado a 32 columnas con barras de bloque (estilo
#  de la foto), pero con datos del COCHE (LMB10 no tiene los euros de Octopus):
#    - Cabecera: LMB10 EFICIENCIA + ciclo elegido
#    - Por dia: consumo kWh/100 km con barra y marca (>) si supera 15,6
#    - Pie de MEDIAS: media kWh/100, mejor/peor dia, total km, autonomia real
#      estimada, kWh totales, nº de cargas
#  Se envia a RawBT (paquete ru.a402d.rawbtprinter) como texto plano; si RawBT
#  no esta, cae a la hoja de compartir normal.
#
# Ejecutar desde la raiz: bash pack_ticket.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_ticket

# ---------------------------------------------------------------------------
# 1) lib/ticket_printer.dart
# ---------------------------------------------------------------------------
cat > lib/ticket_printer.dart << 'EOF'
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
  double? get kwh100 =>
      km > 0 && socDrop > 0 ? socDrop * kTicketBatteryKwh / km : null;
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

Future<List<DayEff>> _computeDays(DateTime from, DateTime to) async {
  final tripRaw = await _tStorage.read(key: 'lm_trip_points_v1');
  final chargeRaw = await _tStorage.read(key: 'lm_charge_history_v1');

  final points = <({int ts, int km, double soc})>[];
  if (tripRaw != null) {
    for (final e in (json.decode(tripRaw) as List)) {
      final m = Map<String, dynamic>.from(e as Map);
      points.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
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
EOF
echo "OK  lib/ticket_printer.dart"

# ---------------------------------------------------------------------------
# 2) lib/ticket_screen.dart
# ---------------------------------------------------------------------------
cat > lib/ticket_screen.dart << 'EOF'
// ticket_screen.dart — Elegir periodo, previsualizar e imprimir el ticket.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ticket_printer.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, this.nickname});
  final String? nickname;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late DateTime _from;
  late DateTime _to;
  String _preview = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 6));
    _rebuild();
  }

  Future<void> _rebuild() async {
    setState(() => _busy = true);
    final t = await buildEfficiencyTicket(
        from: _from, to: _to, nickname: widget.nickname);
    if (!mounted) return;
    setState(() {
      _preview = t;
      _busy = false;
    });
  }

  void _preset(int days) {
    final now = DateTime.now();
    setState(() {
      _to = now;
      _from = now.subtract(Duration(days: days - 1));
    });
    _rebuild();
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (r == null) return;
    setState(() {
      _from = r.start;
      _to = r.end;
    });
    _rebuild();
  }

  Future<void> _print() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final ok = await TicketPrinter.printOrShare(_preview);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (es ? 'Enviado a la impresora' : 'Sent to printer')
            : (es ? 'No se pudo imprimir' : 'Print failed'))));
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Ticket de eficiencia' : 'Efficiency ticket')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(onPressed: () => _preset(7), child: const Text('7 d')),
                OutlinedButton(onPressed: () => _preset(30), child: const Text('30 d')),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(es ? 'Rango' : 'Range'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBEF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: SelectableText(
                        _preview,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.black,
                            height: 1.25),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Clipboard.setData(ClipboardData(text: _preview)),
                      icon: const Icon(Icons.copy),
                      label: Text(es ? 'Copiar' : 'Copy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _print,
                      icon: const Icon(Icons.print),
                      label: Text(es ? 'Imprimir' : 'Print'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
EOF
echo "OK  lib/ticket_screen.dart"

# ---------------------------------------------------------------------------
# 3) main.dart: import + boton Imprimir en el AppBar
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
if "import 'ticket_screen.dart';" not in s:
    anchor = "import 'settings_screen.dart';"
    if s.count(anchor)!=1:
        print(f"ERROR import: ancla x{s.count(anchor)}"); sys.exit(1)
    s = s.replace(anchor, anchor + "\nimport 'ticket_screen.dart';")
    print("OK  import ticket_screen")

anchor_btn = """          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: AppLocalizations.of(context)!.aboutTooltip,"""
new_btn = """          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Ticket de eficiencia' : 'Efficiency ticket',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TicketScreen(nickname: widget.vehicle.nickName),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: AppLocalizations.of(context)!.aboutTooltip,"""
if s.count(anchor_btn)!=1:
    print(f"ERROR boton: ancla x{s.count(anchor_btn)}"); sys.exit(1)
s = s.replace(anchor_btn, new_btn)
print("OK  boton Imprimir en AppBar")
open(p,'w',encoding='utf-8').write(s)
PYEOF

# ---------------------------------------------------------------------------
# 4) MainActivity con canal RawBT
# ---------------------------------------------------------------------------
cat > android/app/src/main/kotlin/com/txurtxil/lpb10/MainActivity.kt << 'EOF'
package com.txurtxil.lpb10

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "lmb10/rawbt"
    private val rawbtPackage = "ru.a402d.rawbtprinter"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "printRawBT") {
                    val text = call.argument<String>("text") ?: ""
                    result.success(sendToRawBT(text))
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun sendToRawBT(text: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                setPackage(rawbtPackage)
                putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
EOF
echo "OK  MainActivity.kt (canal RawBT)"

cat << 'DONE'
============================================================
TICKET TERMICO aplicado. Compila:
  flutter build apk --release
============================================================
DONE
