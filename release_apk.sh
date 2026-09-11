#!/bin/bash
# LMB10 - compila, commitea, pushea y publica GitHub Release con APK + AAB.
# Al publicarse la release, GitHub Actions sube el IPA (macOS) y, si existe
# el secreto PLAY_SERVICE_ACCOUNT, publica el AAB en Google Play.
# Uso: bash release_apk.sh 3.60.138 [/ruta/notas.md] ["Titulo"]
set -e
command -v gh >/dev/null || { echo "ERROR: falta GitHub CLI (gh)."; exit 1; }
[ -f pubspec.yaml ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }

CUR_VER=$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
CUR_NAME=${CUR_VER%%+*}
CUR_BUILD=${CUR_VER##*+}
[ "$CUR_BUILD" = "$CUR_VER" ] && CUR_BUILD=0

if [ -z "$1" ]; then
  echo "ERROR: indica la version (ej: bash release_apk.sh 3.60.138)"
  exit 1
fi
NEW_NAME="$1"
NEW_BUILD=$((CUR_BUILD + 1))

# El tag se comprueba ANTES de tocar pubspec/about: nada de bumps huerfanos.
if gh release view "v${NEW_NAME}" >/dev/null 2>&1; then
  echo "ERROR: la release v${NEW_NAME} ya existe en GitHub. Usa otra version."
  exit 1
fi
if [ -n "$(git tag -l "v${NEW_NAME}")" ]; then
  echo "ERROR: el tag v${NEW_NAME} ya existe en local. Usa otra version."
  exit 1
fi

NOTES_FILE="${2:-}"
REL_TITLE="${3:-LMB10 v${NEW_NAME}}"
echo "Version objetivo: v${NEW_NAME} (build ${NEW_BUILD})"

sed -i -E "s/^version:.*/version: ${NEW_NAME}+${NEW_BUILD}/" pubspec.yaml
sed -i -E "s/(static const String kDisplayVersion = ')[^']*(';)/\1${NEW_NAME}\2/" lib/about_screen.dart

grep -q 'bak_sentry' .gitignore 2>/dev/null || echo '*.bak_sentry' >> .gitignore
grep -q 'backups_widget' .gitignore 2>/dev/null || echo 'backups_widget/' >> .gitignore

echo "== Compilando APK release =="
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

# Notas: fichero del usuario, o autogeneradas desde los commits del ultimo tag.
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  cp "$NOTES_FILE" /tmp/lmb10_notes.md
  echo "Notas: $NOTES_FILE"
else
  ULTIMO_TAG=$(git tag --sort=-v:refname 'v*' | head -1 || true)
  {
    echo "## LMB10 v${NEW_NAME}"
    echo ""
    if [ -n "$ULTIMO_TAG" ]; then
      echo "Cambios desde ${ULTIMO_TAG}:"
      echo ""
      git log --oneline --no-decorate "${ULTIMO_TAG}..HEAD" | sed 's/^/- /'
    else
      git log --oneline --no-decorate -20 | sed 's/^/- /'
    fi
  } > /tmp/lmb10_notes.md
  echo "Notas autogeneradas desde git log (ultimo tag: ${ULTIMO_TAG:-ninguno})"
fi

echo "== Creando release en GitHub (dispara CI: IPA + Play) =="
gh release create "v${NEW_NAME}" "$OUT" "$OUTAAB" \
  --title "$REL_TITLE" \
  --notes-file /tmp/lmb10_notes.md

echo ""
echo "LISTO:"
gh release view "v${NEW_NAME}" --json url -q .url
echo "(Play se publica solo si PLAY_SERVICE_ACCOUNT esta configurado)"
