#!/bin/bash
# LMB10 - compila, commitea, pushea y publica GitHub Release con el APK
# Uso: bash release_apk.sh 3.32.0
set -e
command -v gh >/dev/null || { echo "ERROR: falta GitHub CLI (gh)."; exit 1; }
[ -f pubspec.yaml ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

CUR_VER=$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
CUR_NAME=${CUR_VER%%+*}
CUR_BUILD=${CUR_VER##*+}
[ "$CUR_BUILD" = "$CUR_VER" ] && CUR_BUILD=0

if [ -n "$1" ]; then
  NEW_NAME="$1"
  NEW_BUILD=$((CUR_BUILD + 1))
  sed -i -E "s/^version:.*/version: ${NEW_NAME}+${NEW_BUILD}/" pubspec.yaml
  sed -i -E "s/(static const String kDisplayVersion = ')[^']*(';)/\\1${NEW_NAME}\\2/" lib/about_screen.dart
else
  NEW_NAME="$CUR_NAME"; NEW_BUILD="$CUR_BUILD"
fi
echo "Version objetivo: v${NEW_NAME} (build ${NEW_BUILD})"
# Notas y titulo opcionales: bash release_apk.sh 3.49.0 /tmp/notas.md "Titulo"
NOTES_FILE="${2:-}"
REL_TITLE="${3:-LMB10 v${NEW_NAME}}"

if gh release view "v${NEW_NAME}" >/dev/null 2>&1; then
  echo "ERROR: la release v${NEW_NAME} ya existe. Usa otra (ej: bash release_apk.sh 3.33.0)"
  exit 1
fi

grep -q 'bak_sentry' .gitignore 2>/dev/null || echo '*.bak_sentry' >> .gitignore
grep -q 'backups_widget' .gitignore 2>/dev/null || echo 'backups_widget/' >> .gitignore

echo "== Compilando APK release (con la version nueva) =="
flutter build apk --release
APK=build/app/outputs/flutter-apk/app-release.apk
[ -f "$APK" ] || { echo "ERROR: no se encontro $APK"; exit 1; }
OUT="/tmp/LMB10-v${NEW_NAME}.apk"
cp "$APK" "$OUT"
echo "APK: $OUT ($(du -h "$OUT" | cut -f1))"

echo "== Compilando AAB para Google Play =="
flutter build appbundle --release
AAB=build/app/outputs/bundle/release/app-release.aab
[ -f "$AAB" ] || { echo "ERROR: no se encontro $AAB"; exit 1; }
OUTAAB="/tmp/LMB10-v${NEW_NAME}.aab"
cp "$AAB" "$OUTAAB"
echo "AAB: $OUTAAB ($(du -h "$OUTAAB" | cut -f1))"

echo "== Commit + push =="
git add -A
git commit -m "v${NEW_NAME}: ${REL_TITLE}" || echo "(sin cambios nuevos)"
git push

cat > /tmp/lmb10_notes.md << NOTES
## LMB10 v${NEW_NAME}

### Modo Centinela / Sentry Mode
- Armado en 1 toque; alertas de desbloqueo no solicitado, puertas, porton, encendido (READY) y movimiento/remolcado (GPS).
- Arma el centinela nativo del coche (cmd 220): vibracion -> claxon + luces, funciona con el TCU dormido.
- Opcionales: disuasion claxon+luces (cmd 120) y rebloqueo automatico (cmd 110). Registro de eventos con hora y ubicacion.
- Guia de dashcam por USB (puerto REC) + activacion remota experimental (cmd 290).
- Vigilancia en fondo via WorkManager (recuerda el PIN en el login para comandos en fondo).

### Widget de inicio: consumo diario
- Barras de los ultimos 7 dias en kWh/100 km (odometro + SOC).
- Linea objetivo a 15,6 kWh/100 km (= 67,1 kWh / 430 km de autonomia maxima).
- Rayo verde en dias con carga, linea "Ultima carga: +X% (~Y kWh)" y estado "Cargando" en vivo.
- Widget redimensionable (alto minimo 180dp): quitar y volver a anadir tras actualizar.

Nota: cmd 220 remoto y cmd 290 en el B10 pendientes de verificacion fisica.
NOTES

if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  cp "$NOTES_FILE" /tmp/lmb10_notes.md
  echo "Notas: $NOTES_FILE"
else
  echo "AVISO: sin fichero de notas, se usan las de por defecto (obsoletas)."
fi
echo "== Creando release en GitHub =="
gh release create "v${NEW_NAME}" "$OUT" "$OUTAAB" \
  --title "$REL_TITLE" \
  --notes-file /tmp/lmb10_notes.md

echo ""
echo "Para Google Play, sube este fichero:"
echo "  $OUTAAB"
echo ""
echo "LISTO:"
gh release view "v${NEW_NAME}" --json url -q .url
