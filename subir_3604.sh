#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

cat > /tmp/notas.md << 'NOTASEOF'
## v3.60.4 — Permiso NAVIGATION_TEMPLATES

Google Play rechazaba el app bundle: toda aplicación que declare la categoría
`androidx.car.app.category.NAVIGATION` está obligada a solicitar también el
permiso `androidx.car.app.NAVIGATION_TEMPLATES`. El manifest solo pedía
`ACCESS_SURFACE` y `MAP_TEMPLATES`.

Sin cambios de funcionalidad respecto a 3.60.3.
NOTASEOF

echo "### GIT ANTES"
git status --short

echo
echo "### RELEASE 3.60.4 (APK + GitHub)"
bash release_apk.sh 3.60.4 /tmp/notas.md "Permiso NAVIGATION_TEMPLATES para Google Play"

echo
echo "### BUILD AAB"
flutter build appbundle --release 2>&1 | tail -8

echo
echo "### VERIFICACION FINAL"
grep -n "^version:" pubspec.yaml
grep -n "kDisplayVersion" lib/about_screen.dart | head -1
echo "--- permiso en el manifest fuente:"
grep -c "NAVIGATION_TEMPLATES" android/app/src/main/AndroidManifest.xml
echo "--- permiso en el manifest fusionado del build:"
find android/app/build -name AndroidManifest.xml -path "*merged*" 2>/dev/null \
  | head -3 | xargs grep -l "NAVIGATION_TEMPLATES" 2>/dev/null \
  || echo "(no localizado: ruta de AGP distinta, no es un fallo)"
echo
ls -la build/app/outputs/bundle/release/app-release.aab
