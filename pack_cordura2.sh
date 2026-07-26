#!/bin/bash
# ============================================================================
# LMB10 - pack_cordura2.sh  —  Filtros de cordura calibrados con datos reales
#
#  Problema: un tramo puede contener conduccion Y una carga sin muestrear. El
#  soc neto baja poco mientras los km suben mucho -> consumo falsamente bajo ->
#  autonomia disparatada (caso "6,7 %/100km -> 921 km" + felicitacion).
#
#  Diseno en DOS capas (calibrado contra datos reales, no a ojo):
#   1) Por tramo: rechazar solo lo fisicamente imposible (<8 o >70 %/100km).
#      Verificado: NO altera datos legitimos.
#   2) Red de seguridad: si la media/dia final es implausible (<12 o >70
#      %/100km), no se muestra dato ("--"). Mejor nada que mentir.
#  NO se filtra por hueco temporal: se comprobo que rechaza conduccion real
#  (tramos de 54-73 min con consumo plausible) sin aportar nada, porque una
#  carga oculta ya se detecta por el consumo absurdo.
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz"; exit 1; }
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_cord2
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_cord2
cp lib/ticket_printer.dart backups_widget/ticket_printer.dart.bak_cord2
cp lib/efficiency_coach.dart backups_widget/efficiency_coach.dart.bak_cord2

python3 << 'PYEOF'
import sys, re
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
nueva = """  static double? averageConsumptionPercentPer100km(List<TripPoint> points) {
    // Filtros calibrados con datos reales:
    //  - por tramo: solo se descarta lo fisicamente imposible (no sesga).
    //  - red de seguridad: si la media sale implausible, no se da dato. Un
    //    tramo con conduccion + carga sin muestrear hunde el consumo y
    //    disparaba la autonomia estimada a cifras falsas.
    const minInterval = 8.0; // %/100km imposible por debajo
    const maxInterval = 70.0; // %/100km imposible por encima
    const minAvg = 12.0; // media final creible
    const maxAvg = 70.0;
    double totalKm = 0;
    double totalSocDrop = 0;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final kmDelta = (curr.totalMileage - prev.totalMileage).toDouble();
      final socDelta = prev.soc - curr.soc;
      if (kmDelta <= 0 || socDelta <= 0) continue;
      final pct = socDelta / kmDelta * 100;
      if (pct < minInterval || pct > maxInterval) continue;
      totalKm += kmDelta;
      totalSocDrop += socDelta;
    }
    if (totalKm < 5) return null;
    final avg = (totalSocDrop / totalKm) * 100;
    if (avg < minAvg || avg > maxAvg) return null;
    return avg;
  }"""
m = re.search(r'  static double\? averageConsumptionPercentPer100km\(List<TripPoint> points\) \{.*?\n  \}', s, re.S)
if not m:
    print("ERROR: no encuentro averageConsumptionPercentPer100km"); sys.exit(1)
s = s[:m.start()] + nueva + s[m.end():]
open(p,'w',encoding='utf-8').write(s)
print("OK  main.dart: consumo medio con filtros calibrados")
PYEOF

python3 << 'PYEOF'
import sys
p = 'lib/widget_chart.dart'
s = open(p, encoding='utf-8').read()
old = """      if (kmDelta <= 0 || socDelta <= 0) continue;
      final bar = days[keyOf(curr.ts)];"""
new = """      if (kmDelta <= 0 || socDelta <= 0) continue;
      // Cordura: descartar solo tramos fisicamente imposibles.
      final pct = socDelta / kmDelta * 100;
      if (pct < 8.0 || pct > 70.0) continue;
      final bar = days[keyOf(curr.ts)];"""
if s.count(old)!=1: print(f"ERROR widget tramo: x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
oldg = """  double? get kwh100 =>
      km > 0 && socDrop > 0 ? socDrop * kB10BatteryKwh / km : null;"""
newg = """  double? get kwh100 {
    if (km <= 0 || socDrop <= 0) return null;
    // Red de seguridad: un dia con consumo implausible no se pinta.
    final pct = socDrop / km * 100;
    if (pct < 12.0 || pct > 70.0) return null;
    return socDrop * kB10BatteryKwh / km;
  }"""
if s.count(oldg)!=1: print(f"ERROR widget getter: x{s.count(oldg)}"); sys.exit(1)
s = s.replace(oldg, newg)
open(p,'w',encoding='utf-8').write(s)
print("OK  widget_chart.dart: cordura por tramo + por dia")
PYEOF

python3 << 'PYEOF'
import sys
p = 'lib/ticket_printer.dart'
s = open(p, encoding='utf-8').read()
old = """    if (kmDelta <= 0 || socDelta <= 0) continue;
    final bar = map[keyOf(curr.ts)];"""
new = """    if (kmDelta <= 0 || socDelta <= 0) continue;
    // Cordura: descartar solo tramos fisicamente imposibles.
    final pct = socDelta / kmDelta * 100;
    if (pct < 8.0 || pct > 70.0) continue;
    final bar = map[keyOf(curr.ts)];"""
if s.count(old)!=1: print(f"ERROR ticket tramo: x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
oldg = """  double? get kwh100 =>
      km > 0 && socDrop > 0 ? socDrop * kTicketBatteryKwh / km : null;"""
newg = """  double? get kwh100 {
    if (km <= 0 || socDrop <= 0) return null;
    // Red de seguridad: un dia con consumo implausible no se imprime.
    final pct = socDrop / km * 100;
    if (pct < 12.0 || pct > 70.0) return null;
    return socDrop * kTicketBatteryKwh / km;
  }"""
if s.count(oldg)!=1: print(f"ERROR ticket getter: x{s.count(oldg)}"); sys.exit(1)
s = s.replace(oldg, newg)
open(p,'w',encoding='utf-8').write(s)
print("OK  ticket_printer.dart: cordura por tramo + por dia")
PYEOF

python3 << 'PYEOF'
import sys
p = 'lib/efficiency_coach.dart'
s = open(p, encoding='utf-8').read()
old = """      for (var i = 1; i < pts.length; i++) {
        final kmD = (pts[i].km - pts[i - 1].km).toDouble();
        final socD = pts[i - 1].soc - pts[i].soc;
        if (kmD > 0 && socD > 0) {
          km += kmD;
          drop += socD;
        }
      }"""
new = """      for (var i = 1; i < pts.length; i++) {
        final kmD = (pts[i].km - pts[i - 1].km).toDouble();
        final socD = pts[i - 1].soc - pts[i].soc;
        if (kmD <= 0 || socD <= 0) continue;
        // Cordura: descartar solo tramos fisicamente imposibles.
        final pct = socD / kmD * 100;
        if (pct < 8.0 || pct > 70.0) continue;
        km += kmD;
        drop += socD;
      }"""
if s.count(old)!=1: print(f"ERROR coach bucle: x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
old2 = """      _km = km;
      _media = (km > 0 && drop > 0) ? drop * _battKwh / km : null;"""
new2 = """      _km = km;
      // Red de seguridad: media implausible => no se muestra dato.
      final avgPct = (km >= 5 && drop > 0) ? drop / km * 100 : null;
      _media = (avgPct != null && avgPct >= 12.0 && avgPct <= 70.0)
          ? drop * _battKwh / km
          : null;"""
if s.count(old2)!=1: print(f"ERROR coach media: x{s.count(old2)}"); sys.exit(1)
s = s.replace(old2, new2)
open(p,'w',encoding='utf-8').write(s)
print("OK  efficiency_coach.dart: cordura por tramo + media plausible")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
