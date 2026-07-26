#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp lib/l10n/app_es.arb backups_widget/app_es.arb.bak_$TS
cp lib/l10n/app_en.arb backups_widget/app_en.arb.bak_$TS
cp android/app/src/main/res/layout/battery_widget.xml backups_widget/battery_widget.xml.bak_$TS
echo "[i] Backups en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

# 1a. Filtro en load()
old1 = '''      // chargeState parpadea (regeneracion, enchufado sin cargar...):
      // se ocultan las sesiones cerradas con ganancia < 1%.
      return all.where((s) => s.endTs == null || ((s.endSoc ?? s.startSoc) - s.startSoc) >= 1.0).toList();'''
new1 = '''      // chargeState parpadea (regeneracion, enchufado sin cargar...):
      // se ocultan sesiones cerradas que fueron parpadeos: menos de 3 min
      // enchufado O ganancia de SoC despreciable (< 0.3%). Asi una carga
      // corta real (p. ej. 1% en 20 min) SI cuenta.
      return all.where((s) {
        if (s.endTs == null) return true;
        final gain = (s.endSoc ?? s.startSoc) - s.startSoc;
        final mins = (s.endTs! - s.startTs) / 60000.0;
        return gain >= 0.3 && mins >= 3.0;
      }).toList();'''
if s.count(old1) != 1: sys.exit("ABORT: ancla filtro load x%d" % s.count(old1))
s = s.replace(old1, new1, 1)

# 1b. startSession (ancla REAL: removeLast sin comentario mio)
old2 = '''      final open = sessions.last;
      if (soc - open.startSoc >= 1.0) {
        open.endTs = DateTime.now().millisecondsSinceEpoch;
        open.endSoc = soc;
        await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, soc);
      } else {
        sessions.removeLast();
      }'''
new2 = '''      final open = sessions.last;
      final gain = soc - open.startSoc;
      final mins = (DateTime.now().millisecondsSinceEpoch - open.startTs) / 60000.0;
      if (gain >= 0.3 && mins >= 3.0) {
        open.endTs = DateTime.now().millisecondsSinceEpoch;
        open.endSoc = soc;
        await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, soc);
      } else {
        sessions.removeLast();
      }'''
if s.count(old2) != 1: sys.exit("ABORT: ancla startSession x%d" % s.count(old2))
s = s.replace(old2, new2, 1)

# 1c. reconcileOpenSession
old3 = '''    final endSoc = currentSoc ?? open.startSoc;
    if (endSoc - open.startSoc >= 1.0) {
      open.endTs = DateTime.now().millisecondsSinceEpoch;
      open.endSoc = endSoc;
      await _saveAll(sessions);
      await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, endSoc);
    } else {'''
new3 = '''    final endSoc = currentSoc ?? open.startSoc;
    final gain = endSoc - open.startSoc;
    final mins = (DateTime.now().millisecondsSinceEpoch - open.startTs) / 60000.0;
    if (gain >= 0.3 && mins >= 3.0) {
      open.endTs = DateTime.now().millisecondsSinceEpoch;
      open.endSoc = endSoc;
      await _saveAll(sessions);
      await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, endSoc);
    } else {'''
if s.count(old3) != 1: sys.exit("ABORT: ancla reconcile x%d" % s.count(old3))
s = s.replace(old3, new3, 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] main.dart: umbral por tiempo en 3 sitios")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance main preservado')
"
cp /tmp/pruebatest/main.dart lib/main.dart

sed -i 's/"settingsTooltip": "Ajustes",/"settingsTooltip": "Ajustes, logs y backups",/' lib/l10n/app_es.arb
sed -i 's/"settingsTooltip": "Settings",/"settingsTooltip": "Settings, logs \& backups",/' lib/l10n/app_en.arb
echo "[ok] etiqueta Ajustes (ES/EN)"

cat > android/app/src/main/res/drawable/widget_refresh_bg.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="oval">
    <solid android:color="#0D3B66" />
</shape>
XEOF
echo "[ok] drawable creado"

python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/res/layout/battery_widget.xml"
s = io.open(p, encoding='utf-8').read()
old = '''        <ImageButton
            android:id="@+id/widget_refresh"
            android:layout_width="28dp"
            android:layout_height="28dp"
            android:background="@android:color/transparent"
            android:src="@android:drawable/ic_popup_sync"
            android:contentDescription="Actualizar" />'''
new = '''        <ImageButton
            android:id="@+id/widget_refresh"
            android:layout_width="40dp"
            android:layout_height="40dp"
            android:padding="8dp"
            android:background="@drawable/widget_refresh_bg"
            android:src="@android:drawable/ic_popup_sync"
            android:tint="#FFFFFF"
            android:contentDescription="Actualizar" />'''
if s.count(old) != 1: sys.exit("ABORT: ancla ImageButton x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] widget: boton 40dp oscuro")
PYEOF

echo "[i] Verificacion:"
echo -n "  mins >= 3.0 (3): "; grep -c "mins >= 3.0" lib/main.dart
echo -n "  etiqueta ES (1): "; grep -c "Ajustes, logs y backups" lib/l10n/app_es.arb
echo -n "  drawable: "; ls android/app/src/main/res/drawable/widget_refresh_bg.xml >/dev/null 2>&1 && echo OK
echo -n "  boton 40dp (1): "; grep -c '40dp' android/app/src/main/res/layout/battery_widget.xml
echo -n "  bug \$ main (0): "; grep -c '\\\$' lib/main.dart || true
