#!/bin/bash
# ============================================================================
# LMB10 - ios_port.sh: 3 cambios minimos para compilar la IPA en iOS
#  1) Podfile: descomentar/fijar platform :ios, '14.0'
#  2) project.pbxproj: IPHONEOS_DEPLOYMENT_TARGET 13.0 -> 14.0
#  3) main.dart: inicializar flutter_local_notifications tambien para iOS
#     (DarwinInitializationSettings), como sugiere Kbs23.
# Ejecutar desde la raiz: bash ios_port.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget

# --- 1) Podfile: platform :ios, '14.0' ---
PODFILE=ios/Podfile
if [ -f "$PODFILE" ]; then
  cp "$PODFILE" backups_widget/Podfile.bak_ios
  if grep -qE "^\s*#\s*platform :ios" "$PODFILE"; then
    sed -i -E "s|^\s*#\s*platform :ios.*|platform :ios, '14.0'|" "$PODFILE"
    echo "OK  Podfile: platform :ios, '14.0' (descomentado)"
  elif grep -qE "^\s*platform :ios" "$PODFILE"; then
    sed -i -E "s|^\s*platform :ios.*|platform :ios, '14.0'|" "$PODFILE"
    echo "OK  Podfile: platform :ios, '14.0' (ajustado)"
  else
    sed -i "1i platform :ios, '14.0'" "$PODFILE"
    echo "OK  Podfile: platform :ios, '14.0' (anadido al inicio)"
  fi
else
  echo "AVISO: no existe $PODFILE (se generara con 'flutter build ios'; reejecuta esto despues)"
fi

# --- 2) project.pbxproj: 13.0 -> 14.0 ---
PBX=ios/Runner.xcodeproj/project.pbxproj
if [ -f "$PBX" ]; then
  cp "$PBX" backups_widget/project.pbxproj.bak_ios
  N=$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = 13.0;" "$PBX" || true)
  if [ "$N" -gt 0 ]; then
    sed -i "s|IPHONEOS_DEPLOYMENT_TARGET = 13.0;|IPHONEOS_DEPLOYMENT_TARGET = 14.0;|g" "$PBX"
    echo "OK  project.pbxproj: $N ocurrencia(s) 13.0 -> 14.0"
  else
    echo "AVISO: no habia 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' (revisa el valor manualmente en Xcode)"
  fi
else
  echo "AVISO: no existe $PBX"
fi

# --- 3) main.dart: init iOS en flutter_local_notifications ---
python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()

anchor = """    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(settings: const InitializationSettings(android: androidInit));"""

repl = """    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );"""

n = s.count(anchor)
if n == 1:
    import shutil; shutil.copy(p, 'backups_widget/main.dart.bak_ios')
    s = s.replace(anchor, repl)
    open(p, 'w', encoding='utf-8').write(s)
    print("OK  main.dart: init iOS anadido a _initNotifications")
elif "DarwinInitializationSettings" in s:
    print("OK  main.dart: init iOS ya presente, nada que hacer")
else:
    print(f"AVISO: no encontre el bloque de init de notificaciones esperado ({n} coincidencias).")
    print("      Revisa manualmente _initNotifications: hay que anadir iOS: DarwinInitializationSettings(...) al InitializationSettings.")
PYEOF

echo "-------------------------------------------------------------"
echo "Cambios de iOS aplicados (los que existian en disco)."
echo "Nota: la compilacion de la IPA requiere macOS + Xcode; en"
echo "Linux estos cambios quedan listos para quien compile en Mac."
