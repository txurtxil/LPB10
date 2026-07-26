#!/bin/bash
# ============================================================================
# LMB10 - pack4_controles_widget.sh
#  1) Boton "Controles del vehiculo" movido ARRIBA del todo, encima de la
#     tarjeta de bateria (antes estaba al final del panel).
#  2) Grafico del widget al ESTILO eConsumo: barras anchas con el valor
#     kWh/100 encima de cada una, cabecera con media/objetivo, tus colores
#     (azul/verde) en vez del cian. Mantiene linea roja 430 km y rayos.
# Ejecutar desde la raiz: bash pack4_controles_widget.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_pack4
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_pack4
echo "Backups .bak_pack4 en backups_widget/"

# ---------------------------------------------------------------------------
# 1) Mover el boton Controles: quitarlo de abajo + insertarlo tras el grid
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
path = 'lib/main.dart'
src = open(path, encoding='utf-8').read()

BTN = """                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: Text(AppLocalizations.of(context)!.controlsButton),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      final pin = await _resolvePin();
                      if (pin == null || pin.isEmpty) return;
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ControlsScreen(client: widget.client, vehicle: widget.vehicle, pin: pin),
                        ),
                      );
                      // Al volver de Controles, refresca para ver el efecto real del comando
                      _loadStatus();
                    },
                  ),
                  const SizedBox(height: 8),
"""

if src.count(BTN) != 1:
    print(f"ERROR: bloque del boton Controles encontrado {src.count(BTN)} veces (esperada 1).")
    sys.exit(1)
# 1a) quitarlo de su posicion actual (al final del panel)
src = src.replace(BTN, "")

# 1b) insertarlo justo despues del grid de tiles, antes de la tarjeta de bateria
ANCHOR = """                  _buildTileGrid(s),
                      const SizedBox(height: 12),
                      BatteryWidgetCard("""
if src.count(ANCHOR) != 1:
    print(f"ERROR: ancla del grid/bateria encontrada {src.count(ANCHOR)} veces (esperada 1).")
    sys.exit(1)

TOP_BTN = """                  _buildTileGrid(s),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: Text(AppLocalizations.of(context)!.controlsButton),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      final pin = await _resolvePin();
                      if (pin == null || pin.isEmpty) return;
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ControlsScreen(client: widget.client, vehicle: widget.vehicle, pin: pin),
                        ),
                      );
                      _loadStatus();
                    },
                  ),
                      const SizedBox(height: 12),
                      BatteryWidgetCard("""

src = src.replace(ANCHOR, TOP_BTN)
open(path, 'w', encoding='utf-8').write(src)
print("OK  boton Controles movido arriba (encima de bateria)")
PYEOF

# ---------------------------------------------------------------------------
# 2) Grafico del widget estilo eConsumo (reemplaza _renderChartPng)
# ---------------------------------------------------------------------------
python3 - << 'PYEOF'
src = open('lib/widget_chart.dart', encoding='utf-8').read()
start = src.index('Future<List<int>> _renderChartPng')
end = src.index('void _drawBolt')
new_render = '''Future<List<int>> _renderChartPng(List<_DayBar> bars, double? weekAvg) async {
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
      tpOf('objetivo ${_d1(kTargetKwh100)} kWh/100 = 430 km', 22, _cBlue);
  sub.paint(canvas, const Offset(leftPad, 58));
  if (weekAvg != null) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
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

'''
src = src[:start] + new_render + src[end:]
open('lib/widget_chart.dart', 'w', encoding='utf-8').write(src)
print('OK  grafico del widget estilo eConsumo')
PYEOF

cat << 'DONE'
============================================================
PACK 4 APLICADO. Compila:
  flutter build apk --release
============================================================
DONE
