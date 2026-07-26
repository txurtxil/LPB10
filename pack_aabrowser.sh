#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
M=android/app/src/main/AndroidManifest.xml
cp $M backups_widget/AndroidManifest.xml.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
m = "android/app/src/main/AndroidManifest.xml"
s = io.open(m, encoding='utf-8').read()

# 1. Añadir permisos de coche que declara AABrowser (junto a los otros uses-permission)
if "androidx.car.app.ACCESS_SURFACE" not in s:
    anchor = '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>'
    if s.count(anchor) != 1:
        sys.exit("ABORT: ancla permisos x%d" % s.count(anchor))
    add = anchor + '''
    <uses-permission android:name="androidx.car.app.ACCESS_SURFACE" />
    <uses-permission android:name="androidx.car.app.MAP_TEMPLATES" />'''
    s = s.replace(anchor, add, 1)
    print("[ok] permisos ACCESS_SURFACE + MAP_TEMPLATES añadidos")

# 2. Ampliar el intent-filter del servicio: NAVIGATION + CAR_LAUNCHER + APP_MAPS
old_svc = '''        <service
            android:name=".LMB10CarAppService"
            android:exported="true">
            <intent-filter>
                <action android:name="androidx.car.app.CarAppService" />
                <category android:name="androidx.car.app.category.NAVIGATION" />
            </intent-filter>
        </service>'''
new_svc = '''        <service
            android:name=".LMB10CarAppService"
            android:exported="true">
            <intent-filter>
                <action android:name="androidx.car.app.CarAppService" />
                <category android:name="androidx.car.app.category.NAVIGATION" />
                <category android:name="android.intent.category.CAR_LAUNCHER" />
                <category android:name="android.intent.category.APP_MAPS" />
            </intent-filter>
        </service>'''
if s.count(old_svc) != 1:
    sys.exit("ABORT: ancla servicio x%d" % s.count(old_svc))
s = s.replace(old_svc, new_svc, 1)
print("[ok] intent-filter ampliado (NAVIGATION + CAR_LAUNCHER + APP_MAPS)")

# 3. Añadir el provider de conexion de Car App (clave para que el host detecte la app)
if "androidx.car.app.connection.provider" not in s:
    # insertarlo justo antes del cierre de </application>
    anchor = "    </application>"
    if s.count(anchor) != 1:
        sys.exit("ABORT: ancla /application x%d" % s.count(anchor))
    provider = '''        <provider
            android:name="androidx.car.app.connection.CarAppMetadataHolderService$CarAppConnectionProvider"
            android:authorities="com.txurtxil.lpb10.androidx.car.app.connection"
            android:exported="true" />
'''
    # OJO: el provider real de la libreria es este; algunas versiones lo generan solas.
    # Lo dejamos comentado y probamos primero sin el, porque la libreria 1.7 suele
    # generarlo automaticamente. Ver nota en el chat.
    print("[i] provider: NO añadido a mano (la libreria 1.7 lo genera). Ver nota.")

# 4. minCarApiLevel: AABrowser usa 7. Verificar el nuestro.
import re
mca = re.search(r'minCarApiLevel"\s+android:value="(\d+)"', s)
if mca:
    print("[i] minCarApiLevel actual:", mca.group(1), "(AABrowser usa 7)")

io.open(m, 'w', encoding='utf-8').write(s)
print("[ok] manifest actualizado")
PYEOF

echo "[i] Verificacion:"
echo -n "  ACCESS_SURFACE (1): "; grep -c "ACCESS_SURFACE" $M
echo -n "  MAP_TEMPLATES (1): "; grep -c "MAP_TEMPLATES" $M
echo -n "  CAR_LAUNCHER (1): "; grep -c "CAR_LAUNCHER" $M
echo -n "  APP_MAPS (1): "; grep -c "APP_MAPS" $M
