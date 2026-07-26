#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
D=android/app/src/main/res/drawable
cp $K/QuickActionsScreen.kt backups_widget/QuickActionsScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

# Iconos nuevos: cerrar maletero (caja cerrada), volante (circulo), desbloquear cargador (enchufe), apagar precalentado
cat > $D/ic_qa_trunk_close.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M20,6h-8l-2,-2H4c-1.1,0 -1.99,0.9 -1.99,2L2,18c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2V8c0,-1.1 -0.9,-2 -2,-2zM20,18H4V8h16v10zM13,9l-1.5,0l0,3l-2,0l2.5,3l2.5,-3l-2,0z"/>
</vector>
X

cat > $D/ic_qa_wheel.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM12,4c3.35,0 6.19,2.24 7.1,5.3 -1.3,-0.79 -3.36,-1.3 -7.1,-1.3s-5.8,0.51 -7.1,1.3C5.81,6.24 8.65,4 12,4zM11,19.93C7.05,19.44 4,16.08 4,12c0,-0.11 0.01,-0.22 0.02,-0.33C5.4,12.5 7.96,13 11,13v6.93zM13,19.93V13c3.04,0 5.6,-0.5 6.98,-1.33 0.01,0.11 0.02,0.22 0.02,0.33 0,4.08 -3.05,7.44 -7,7.93z"/>
</vector>
X

cat > $D/ic_qa_charger.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M14.69,2.21L4.33,11.49c-0.64,0.58 -0.28,1.65 0.58,1.73L13,14l-4.85,6.76c-0.22,0.31 0.19,0.69 0.49,0.45l10.36,-9.28c0.64,-0.58 0.28,-1.65 -0.58,-1.73L11,9l4.85,-6.76c0.22,-0.31 -0.19,-0.69 -0.49,-0.45z"/>
</vector>
X

echo "[ok] iconos nuevos creados"

python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/QuickActionsScreen.kt"
s = io.open(p, encoding='utf-8').read()

# Añadir las 4 acciones nuevas a la lista, tras preheat
old = '''        QA("preheat", "Precalentar", R.drawable.ic_qa_preheat)
    )'''
new = '''        QA("preheat", "Precalentar", R.drawable.ic_qa_preheat),
        QA("trunk_close", "Cerrar maletero", R.drawable.ic_qa_trunk_close),
        QA("wheel_heat", "Volante calef.", R.drawable.ic_qa_wheel),
        QA("charger_unlock", "Liberar cargador", R.drawable.ic_qa_charger)
    )'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla lista acciones x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] QuickActionsScreen: 3 botones nuevos añadidos")
PYEOF

echo "[i] Verificacion:"
echo -n "  botones nuevos en pantalla (3): "; grep -c "trunk_close\|wheel_heat\|charger_unlock" $K/QuickActionsScreen.kt
echo -n "  iconos creados (3): "; ls $D/ic_qa_trunk_close.xml $D/ic_qa_wheel.xml $D/ic_qa_charger.xml 2>/dev/null | wc -l
