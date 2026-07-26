#!/bin/bash
# ============================================================================
# LMB10 - pack_widget_text.sh  —  Grafico del widget con BARRAS DE TEXTO
#  Los widgets Android no pueden dibujar graficos salvo como imagen (PNG), y el
#  PNG estaba fallando. Solucion robusta: grafico como TEXTO monoespaciado con
#  barras de bloque en un TextView nativo -> NUNCA desaparece.
# Ejecutar desde la raiz: bash pack_widget_text.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz del proyecto"; exit 1; }
mkdir -p backups_widget
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_text
cp android/app/src/main/res/layout/battery_widget.xml backups_widget/battery_widget.xml.bak_text
cp android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt backups_widget/BatteryWidgetProvider.kt.bak_text

python3 << 'PYEOF'
import sys
p = 'lib/widget_chart.dart'
s = open(p, encoding='utf-8').read()
def one(a,b,label):
    global s
    if s.count(a)!=1: print(f"ERROR '{label}': x{s.count(a)}"); sys.exit(1)
    s=s.replace(a,b); print(f"OK  {label}")

one("  String chartPath = '';",
    "  String chartPath = '';\n  String chartText = '';",
    'decl chartText')
one("""    final hasData =
        bars.any((b) => b.kwh100 != null) || bars.any((b) => b.charged);""",
    """    try {
      chartText = _buildTextChart(bars, weekAvg);
    } catch (_) {}

    final hasData =
        bars.any((b) => b.kwh100 != null) || bars.any((b) => b.charged);""",
    'generar chartText')
one("    'realRange': realRange,",
    "    'realRange': realRange,\n    'chartText': chartText,",
    'return chartText')
one("Future<List<int>> _renderChartPng(List<_DayBar> bars, double? weekAvg) async {",
    """String _buildTextChart(List<_DayBar> bars, double? weekAvg) {
  final withData = bars.where((b) => b.kwh100 != null).toList();
  final maxVal = withData.isEmpty
      ? kTargetKwh100
      : withData.map((b) => b.kwh100!).reduce((a, x) => a > x ? a : x);
  const barMax = 8;
  final sb = StringBuffer();
  sb.writeln('Consumo kWh/100  obj ${_d1(kTargetKwh100)}');
  for (final b in bars) {
    final v = b.kwh100;
    final bolt = b.charged ? ' \\u26A1' : '';
    if (v == null) {
      sb.writeln('${b.label} ${'\\u2591' * barMax}    --$bolt');
      continue;
    }
    final blocks =
        maxVal <= 0 ? 0 : (v / maxVal * barMax).round().clamp(0, barMax);
    final bar = '\\u2588' * blocks + '\\u2591' * (barMax - blocks);
    final over = v > kTargetKwh100 ? '>' : ' ';
    sb.writeln('${b.label} $bar ${_d1(v).padLeft(4)}$over$bolt');
  }
  if (weekAvg != null) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    sb.writeln('Media 7d ${_d1(weekAvg)}  ~$estFull km');
  }
  return sb.toString().trimRight();
}

Future<List<int>> _renderChartPng(List<_DayBar> bars, double? weekAvg) async {""",
    'definir _buildTextChart')
open(p,'w',encoding='utf-8').write(s)
print("OK  widget_chart.dart listo")
PYEOF

python3 << 'PYEOF'
import sys
p = 'android/app/src/main/res/layout/battery_widget.xml'
s = open(p, encoding='utf-8').read()
old = """    <ImageView
        android:id="@+id/widget_chart"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:layout_marginTop="6dp"
        android:scaleType="fitCenter"
        android:visibility="gone"
        android:contentDescription="Consumo diario" />"""
new = """    <TextView
        android:id="@+id/widget_chart_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:fontFamily="monospace"
        android:textSize="13sp"
        android:lineSpacingExtra="2dp"
        android:textColor="#0D3B66"
        android:visibility="gone" />"""
if s.count(old)!=1:
    print(f"ERROR layout: ancla x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  layout: ImageView -> TextView")
PYEOF

python3 << 'PYEOF'
import sys
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt'
s = open(p, encoding='utf-8').read()
old = """        var chartShown = false
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
        if (!chartShown) views.setViewVisibility(R.id.widget_chart, View.GONE)"""
new = """        val chartText = prefs.getString("chartText", null)
        if (large && !chartText.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_chart_text, chartText)
            views.setViewVisibility(R.id.widget_chart_text, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_chart_text, View.GONE)
        }"""
if s.count(old)!=1:
    print(f"ERROR provider: ancla x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  provider: chartText en TextView")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
