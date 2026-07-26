#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
D=android/app/src/main/res/drawable
cp $K/QuickActionsScreen.kt backups_widget/QuickActionsScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

# ===== Crear los 9 iconos vectoriales =====
# Candado cerrado
cat > $D/ic_qa_lock.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M12,17c1.1,0 2,-0.9 2,-2s-0.9,-2 -2,-2 -2,0.9 -2,2 0.9,2 2,2zM18,8h-1V6c0,-2.76 -2.24,-5 -5,-5S7,3.24 7,6v2H6c-1.1,0 -2,0.9 -2,2v10c0,1.1 0.9,2 2,2h12c1.1,0 2,-0.9 2,-2V10c0,-1.1 -0.9,-2 -2,-2zM9,6c0,-1.66 1.34,-3 3,-3s3,1.34 3,3v2H9V6zM18,20H6V10h12v10z"/>
</vector>
X

# Candado abierto
cat > $D/ic_qa_unlock.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M12,17c1.1,0 2,-0.9 2,-2s-0.9,-2 -2,-2 -2,0.9 -2,2 0.9,2 2,2zM18,8h-1V6c0,-2.76 -2.24,-5 -5,-5 -2.28,0 -4.27,1.54 -4.84,3.75l1.93,0.51C10.42,4.99 11.14,4 12,4c1.66,0 3,1.34 3,3v1H6c-1.1,0 -2,0.9 -2,2v10c0,1.1 0.9,2 2,2h12c1.1,0 2,-0.9 2,-2V10c0,-1.1 -0.9,-2 -2,-2zM18,20H6V10h12v10z"/>
</vector>
X

# Sol (calor)
cat > $D/ic_qa_heat.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M12,7c-2.76,0 -5,2.24 -5,5s2.24,5 5,5 5,-2.24 5,-5 -2.24,-5 -5,-5zM2,13h2c0.55,0 1,-0.45 1,-1s-0.45,-1 -1,-1H2c-0.55,0 -1,0.45 -1,1s0.45,1 1,1zM20,13h2c0.55,0 1,-0.45 1,-1s-0.45,-1 -1,-1h-2c-0.55,0 -1,0.45 -1,1s0.45,1 1,1zM11,2v2c0,0.55 0.45,1 1,1s1,-0.45 1,-1V2c0,-0.55 -0.45,-1 -1,-1s-1,0.45 -1,1zM11,20v2c0,0.55 0.45,1 1,1s1,-0.45 1,-1v-2c0,-0.55 -0.45,-1 -1,-1s-1,0.45 -1,1zM5.99,4.58c-0.39,-0.39 -1.03,-0.39 -1.41,0 -0.39,0.39 -0.39,1.03 0,1.41l1.06,1.06c0.39,0.39 1.03,0.39 1.41,0s0.39,-1.03 0,-1.41L5.99,4.58zM18.36,16.95c-0.39,-0.39 -1.03,-0.39 -1.41,0 -0.39,0.39 -0.39,1.03 0,1.41l1.06,1.06c0.39,0.39 1.03,0.39 1.41,0 0.39,-0.39 0.39,-1.03 0,-1.41l-1.06,-1.06zM19.42,5.99c0.39,-0.39 0.39,-1.03 0,-1.41 -0.39,-0.39 -1.03,-0.39 -1.41,0l-1.06,1.06c-0.39,0.39 -0.39,1.03 0,1.41s1.03,0.39 1.41,0l1.06,-1.06zM7.05,18.36c0.39,-0.39 0.39,-1.03 0,-1.41 -0.39,-0.39 -1.03,-0.39 -1.41,0l-1.06,1.06c-0.39,0.39 -0.39,1.03 0,1.41s1.03,0.39 1.41,0l1.06,-1.06z"/>
</vector>
X

# Copo de nieve (frio)
cat > $D/ic_qa_cool.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M22,11h-4.17l3.24,-3.24 -1.41,-1.42L15,11h-2V9l4.66,-4.66 -1.42,-1.41L13,6.17V2h-2v4.17L7.76,2.93 6.34,4.34 11,9v2H9L4.34,6.34 2.93,7.76 6.17,11H2v2h4.17l-3.24,3.24 1.41,1.42L9,13h2v2l-4.66,4.66 1.42,1.41L11,17.83V22h2v-4.17l3.24,3.24 1.42,-1.41L13,15v-2h2l4.66,4.66 1.41,-1.42L17.83,13H22z"/>
</vector>
X

# Desempanar (lineas de calor sobre cristal)
cat > $D/ic_qa_defrost.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M9.5,6c0,1.11 -0.89,2 -2,2C5.84,8 4.5,9.34 4.5,11h-2C2.5,8.24 4.74,6 7.5,6c0.55,0 1,-0.45 1,-1s-0.45,-1 -1,-1c-1.66,0 -3,-1.34 -3,-3h2c0,0.55 0.45,1 1,1 1.66,0 3,1.34 3,3zM19.5,15c0,-1.11 -0.89,-2 -2,-2 -1.66,0 -3,-1.34 -3,-3h2c0,0.55 0.45,1 1,1 1.66,0 3,1.34 3,3 0,2.76 -2.24,5 -5,5 -0.55,0 -1,0.45 -1,1s0.45,1 1,1c1.66,0 3,1.34 3,3h-2c0,-0.55 -0.45,-1 -1,-1 -1.66,0 -3,-1.34 -3,-3s1.34,-3 3,-3c1.11,0 2,-0.89 2,-2zM11.5,13c0,1.66 -1.34,3 -3,3 -0.55,0 -1,0.45 -1,1s0.45,1 1,1c1.66,0 3,1.34 3,3h-2c0,-0.55 -0.45,-1 -1,-1 -1.66,0 -3,-1.34 -3,-3s1.34,-3 3,-3c1.11,0 2,-0.89 2,-2h2z"/>
</vector>
X

# Buscar coche (faro/altavoz)
cat > $D/ic_qa_find.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M12,2C8.13,2 5,5.13 5,9c0,5.25 7,13 7,13s7,-7.75 7,-13c0,-3.87 -3.13,-7 -7,-7zM12,11.5c-1.38,0 -2.5,-1.12 -2.5,-2.5s1.12,-2.5 2.5,-2.5 2.5,1.12 2.5,2.5 -1.12,2.5 -2.5,2.5z"/>
</vector>
X

# Maletero (caja)
cat > $D/ic_qa_trunk.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M20,6h-8l-2,-2H4c-1.1,0 -1.99,0.9 -1.99,2L2,18c0,1.1 0.9,2 2,2h16c1.1,0 2,-0.9 2,-2V8c0,-1.1 -0.9,-2 -2,-2zM20,18H4V8h16v10z"/>
</vector>
X

# Centinela (escudo)
cat > $D/ic_qa_sentry.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M12,1L3,5v6c0,5.55 3.84,10.74 9,12 5.16,-1.26 9,-6.45 9,-12V5l-9,-4zM12,11.99h7c-0.53,4.12 -3.28,7.79 -7,8.94V12H5V6.3l7,-3.11v8.8z"/>
</vector>
X

# Precalentar bateria (bateria con rayo)
cat > $D/ic_qa_preheat.xml <<'X'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24" android:tint="#FFFFFF">
<path android:fillColor="#FFF" android:pathData="M15.67,4H14V2h-4v2H8.33C7.6,4 7,4.6 7,5.33v15.33C7,21.4 7.6,22 8.33,22h7.33c0.74,0 1.34,-0.6 1.34,-1.33V5.33C17,4.6 16.4,4 15.67,4zM11,20v-5.5H9L13,7v5.5h2L11,20z"/>
</vector>
X

echo "[ok] 9 iconos vectoriales creados"

# ===== Asignar los iconos en QuickActionsScreen =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/QuickActionsScreen.kt"
s = io.open(p, encoding='utf-8').read()

old = '''    private val actions = listOf(
        QA("lock", "Cerrar", R.drawable.ic_car_battery),
        QA("unlock", "Abrir", R.drawable.ic_car_battery),
        QA("heat", "Calor", R.drawable.ic_car_battery),
        QA("cool", "Frio", R.drawable.ic_car_battery),
        QA("defrost", "Desempanar", R.drawable.ic_car_battery),
        QA("find", "Buscar coche", R.drawable.ic_car_routine),
        QA("trunk", "Maletero", R.drawable.ic_car_battery),
        QA("sentry_on", "Centinela ON", R.drawable.ic_car_battery),
        QA("preheat", "Precalentar", R.drawable.ic_car_battery)
    )'''
new = '''    private val actions = listOf(
        QA("lock", "Cerrar", R.drawable.ic_qa_lock),
        QA("unlock", "Abrir", R.drawable.ic_qa_unlock),
        QA("heat", "Calor", R.drawable.ic_qa_heat),
        QA("cool", "Frio", R.drawable.ic_qa_cool),
        QA("defrost", "Desempanar", R.drawable.ic_qa_defrost),
        QA("find", "Buscar coche", R.drawable.ic_qa_find),
        QA("trunk", "Maletero", R.drawable.ic_qa_trunk),
        QA("sentry_on", "Centinela ON", R.drawable.ic_qa_sentry),
        QA("preheat", "Precalentar", R.drawable.ic_qa_preheat)
    )'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla actions x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] QuickActionsScreen: iconos propios asignados")
PYEOF

echo "[i] Verificacion:"
echo -n "  iconos nuevos asignados (9): "; grep -c "ic_qa_" $K/QuickActionsScreen.kt
echo -n "  ya no usa ic_car_battery (0): "; grep -c "ic_car_battery" $K/QuickActionsScreen.kt || true
echo -n "  ficheros drawable creados (9): "; ls $D/ic_qa_*.xml 2>/dev/null | wc -l
