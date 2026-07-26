#!/bin/bash
# ============================================================================
# LMB10 - reorganiza_pack3.sh
#  1) GRAFICO DEL WIDGET rediseñado: tipografia grande y legible, panel
#     blanco redondeado, rejilla suave, misma logica (verde/naranja vs 15,6).
#  2) BOTON DE AJUSTES -> MENU: la rueda del AppBar despliega Ajustes,
#     Exportar historico, Importar backup, Modo vigilancia (exp.) y Debug.
#     Se ELIMINAN del panel: Exportar historico, Modo vigilancia, Debug,
#     Mensajes y "Exportar datos (JSON anonimizado)".
#  3) MENSAJES -> icono de sobre junto a la rueda, con globo del numero de
#     no leidos (endpoint oficial /message/v1/unread/count del motor).
#  4) IMPORTAR BACKUP: restaura viajes y cargas desde el JSON exportado
#     (file_picker) hacia los stores y el archivo permanente.
# Ejecutar desde la raiz: bash reorganiza_pack3.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_pack3
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_pack3
cp lib/history_archive.dart backups_widget/history_archive.dart.bak_pack3
echo "Backups .bak_pack3 en backups_widget/"

if command -v flutter >/dev/null; then
  grep -q "file_picker" pubspec.yaml || flutter pub add file_picker
else
  echo "AVISO: ejecuta luego 'flutter pub add file_picker'"
fi

# ---------------------------------------------------------------------------
# 1) Parches a main.dart e history_archive.dart
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

patch('lib/main.dart', [
 ('campo contador no leidos',
  "  bool _refreshing = false;",
  "  bool _refreshing = false;\n  int _unreadMsgs = 0;"),

 ('refrescar no leidos al arrancar',
  """    loadShowMapSetting().then((v) { if (mounted) setState(() => _showMap = v); });
    _loadStatus();""",
  """    loadShowMapSetting().then((v) { if (mounted) setState(() => _showMap = v); });
    _loadStatus();
    _refreshUnread();"""),

 ('metodo _refreshUnread',
  "  Future<void> _loadStatus({bool retryOnTransient = true}) async {",
  """  Future<void> _refreshUnread() async {
    try {
      final n = await widget.client.getUnreadMessageCount();
      if (mounted) setState(() => _unreadMsgs = n);
    } catch (_) {}
  }

  Future<void> _loadStatus({bool retryOnTransient = true}) async {"""),

 ('refrescar no leidos en cada refresco',
  "      setState(() { _status = status; _refreshing = false; _lastFetched = DateTime.now(); _transientError = null; });",
  """      setState(() { _status = status; _refreshing = false; _lastFetched = DateTime.now(); _transientError = null; });
      _refreshUnread();"""),

 ('sobre con globo + menu en la rueda',
  """          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.settingsTooltip,
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              final v = await loadShowMapSetting();
              if (mounted) setState(() => _showMap = v);
            },
          ),""",
  """          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Mensajes' : 'Messages',
            icon: Badge(
              isLabelVisible: _unreadMsgs > 0,
              label: Text(_unreadMsgs > 9 ? '9+' : '$_unreadMsgs'),
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(client: widget.client)));
              _refreshUnread();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.settingsTooltip,
            onSelected: (v) async {
              final es = Localizations.localeOf(context).languageCode == 'es';
              switch (v) {
                case 'settings':
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  final s = await loadShowMapSetting();
                  if (mounted) setState(() => _showMap = s);
                  break;
                case 'export':
                  final ok = await exportHistoryAndShare();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? (es ? 'Backup generado' : 'Backup created') : (es ? 'No se pudo exportar' : 'Export failed'))),
                  );
                  break;
                case 'import':
                  final msg = await importHistoryBackup();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  _loadStatus();
                  break;
                case 'guard':
                  final pin = await _resolvePin();
                  if (pin == null || pin.isEmpty) return;
                  if (!mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GuardModeScreen(client: widget.client, vehicle: widget.vehicle, pin: pin)),
                  );
                  _loadStatus();
                  break;
                case 'debug':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DebugStatusScreen(client: widget.client, vehicle: widget.vehicle)),
                  );
                  break;
              }
            },
            itemBuilder: (context) {
              final es = Localizations.localeOf(context).languageCode == 'es';
              return [
                PopupMenuItem(value: 'settings', child: ListTile(dense: true, leading: const Icon(Icons.tune), title: Text(AppLocalizations.of(context)!.settingsTooltip))),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'export', child: ListTile(dense: true, leading: const Icon(Icons.download), title: Text(es ? 'Exportar historico' : 'Export history'))),
                PopupMenuItem(value: 'import', child: ListTile(dense: true, leading: const Icon(Icons.upload), title: Text(es ? 'Importar backup' : 'Import backup'))),
                PopupMenuItem(value: 'guard', child: ListTile(dense: true, leading: const Icon(Icons.shield_outlined), title: Text(AppLocalizations.of(context)!.guardModeButton))),
                PopupMenuItem(value: 'debug', child: ListTile(dense: true, leading: const Icon(Icons.bug_report_outlined), title: Text(AppLocalizations.of(context)!.debugButton))),
              ];
            },
          ),"""),

 ('quitar boton Exportar historico del panel',
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
""",
  ""),

 ('quitar boton Modo vigilancia del panel',
  """                  OutlinedButton.icon(
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: Text(AppLocalizations.of(context)!.guardModeButton),
                    onPressed: () async {
                      final pin = await _resolvePin();
                      if (pin == null || pin.isEmpty) return;
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GuardModeScreen(client: widget.client, vehicle: widget.vehicle, pin: pin),
                        ),
                      );
                      _loadStatus();
                    },
                  ),
                  const SizedBox(height: 8),
""",
  ""),

 ('quitar boton Mensajes del panel',
  """                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.mail_outline, size: 18),
                    label: Text(AppLocalizations.of(context)!.messagesButton),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(client: widget.client)));
                    },
                  ),
""",
  ""),

 ('quitar boton JSON anonimizado',
  """                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.ios_share, size: 18),
                    label: Text(AppLocalizations.of(context)!.exportButton),
                    onPressed: () => exportAnonymizedJson(context, widget.vehicle),
                  ),
""",
  ""),

 ('quitar boton Debug del panel',
  """                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: Text(AppLocalizations.of(context)!.debugButton),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DebugStatusScreen(client: widget.client, vehicle: widget.vehicle)),
                      );
                    },
                  ),
""",
  ""),
])

patch('lib/history_archive.dart', [
 ('import file_picker',
  "import 'package:share_plus/share_plus.dart';",
  "import 'package:share_plus/share_plus.dart';\nimport 'package:file_picker/file_picker.dart';"),
])
print('OK  parches aplicados')
PYEOF

# ---------------------------------------------------------------------------
# 2) Funcion de importacion (se anade al final de history_archive.dart)
# ---------------------------------------------------------------------------
cat >> lib/history_archive.dart << 'EOF'

/// Importa un backup JSON generado por "Exportar historico": restaura los
/// stores de la app (ultimos 200 puntos / 25 cargas) y lo vuelca entero al
/// archivo permanente. Devuelve el mensaje para el SnackBar.
Future<String> importHistoryBackup() async {
  try {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (res == null || res.files.isEmpty) return 'Importacion cancelada';
    final f = res.files.single;
    String? content;
    if (f.bytes != null) {
      content = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      content = await File(f.path!).readAsString();
    }
    if (content == null) return 'No se pudo leer el fichero';

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

    // Archivo permanente (la exportacion deduplica por timestamp)
    for (final t in tp) {
      await HistoryArchive.appendTrip(
          t['ts'] as int, t['km'] as int, (t['soc'] as num).toDouble());
    }
    for (final c in ch) {
      final endV = c['endTs'];
      final socV = c['endSoc'];
      if (endV is int && socV is num) {
        await HistoryArchive.appendCharge(c['startTs'] as int, endV,
            (c['startSoc'] as num).toDouble(), socV.toDouble());
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
    return 'Importado: ${tp.length} puntos de viaje, ${ch.length} cargas';
  } catch (_) {
    return 'Backup no valido';
  }
}
EOF
echo "OK  importHistoryBackup en history_archive.dart"

# ---------------------------------------------------------------------------
# 3) Grafico v3: tipografia grande, panel y rejilla (regenerado completo)
# ---------------------------------------------------------------------------
python3 - << 'PYEOF'
src = open('lib/widget_chart.dart', encoding='utf-8').read()
start = src.index('Future<List<int>> _renderChartPng')
end = src.index('void _drawBolt')
new_render = '''Future<List<int>> _renderChartPng(List<_DayBar> bars, double? weekAvg) async {
  const w = 660.0, h = 480.0;
  const leftPad = 22.0, rightPad = 22.0, topPad = 104.0, bottomPad = 104.0;
  final plotW = w - leftPad - rightPad;
  final plotH = h - topPad - bottomPad;
  final plotBottom = topPad + plotH;
  final slotW = plotW / bars.length;
  final barW = slotW * 0.58;

  final values = bars.map((b) => b.kwh100 ?? 0.0).toList();
  final maxVal = math.max(values.fold(0.0, math.max), kTargetKwh100) * 1.32;
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

  // Panel blanco redondeado (aspecto tarjeta)
  final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, w - 8, h - 8), const Radius.circular(28));
  canvas.drawRRect(panel, Paint()..color = const Color(0x78FFFFFF));
  canvas.drawRRect(
      panel,
      Paint()
        ..color = _cBlue.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);

  // Titulo y media semanal
  final legend =
      tpOf('kWh/100 km  ·  objetivo ${_d1(kTargetKwh100)} = 430 km', 25, _cBlue,
          weight: FontWeight.w700);
  legend.paint(canvas, const Offset(leftPad, 18));
  if (weekAvg != null) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    final ok = weekAvg <= kTargetKwh100;
    final sum = tpOf('Media 7d: ${_d1(weekAvg)}  =  ~$estFull km/carga', 25,
        ok ? _cGood : _cOver,
        weight: FontWeight.w700);
    sum.paint(canvas, const Offset(leftPad, 56));
  }

  // Rejilla horizontal suave cada 5 kWh/100km
  final gridPaint = Paint()
    ..color = _cBlue.withOpacity(0.10)
    ..strokeWidth = 2;
  for (double g = 5; g < maxVal; g += 5) {
    final y = yOf(g);
    canvas.drawLine(Offset(leftPad, y), Offset(w - rightPad, y), gridPaint);
  }

  // Eje base
  canvas.drawLine(
      Offset(leftPad, plotBottom),
      Offset(w - rightPad, plotBottom),
      Paint()
        ..color = _cBlue.withOpacity(0.30)
        ..strokeWidth = 3);

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
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      );
      canvas.drawRRect(rect, Paint()..color = color);
      final lbl = tpOf(_d1(v), 30, color, weight: FontWeight.w800);
      lbl.paint(canvas, Offset(cx - lbl.width / 2, top - 40));
    }
    // Dia del mes
    final day = tpOf(b.label, 30, _cBlue, weight: FontWeight.w700);
    day.paint(canvas, Offset(cx - day.width / 2, plotBottom + 10));
    // Rayo (+ kWh cargados)
    if (b.charged) {
      if (b.chargedKwh > 0.05) {
        final kw = tpOf('+${_d1(b.chargedKwh)}', 22, _cGood,
            weight: FontWeight.w800);
        final total = 26 + 6 + kw.width;
        final startX = cx - total / 2;
        _drawBolt(canvas, Offset(startX + 13, plotBottom + 64), 13, _cGood);
        kw.paint(canvas, Offset(startX + 32, plotBottom + 50));
      } else {
        _drawBolt(canvas, Offset(cx, plotBottom + 64), 13, _cGood);
      }
    }
  }

  // Linea objetivo discontinua
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

'''
src = src[:start] + new_render + src[end:]
open('lib/widget_chart.dart', 'w', encoding='utf-8').write(src)
print('OK  grafico v3 (tipografia grande + panel + rejilla)')
PYEOF

cat << 'DONE'
============================================================
PACK 3 APLICADO. Compila:
  flutter build apk --release
============================================================
DONE
