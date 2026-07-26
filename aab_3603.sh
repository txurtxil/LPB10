#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

echo "### FIRMA: estado real antes de compilar"
if [ -f android/key.properties ]; then
  echo "key.properties existe. Rutas declaradas:"
  grep -E "storeFile|keyAlias" android/key.properties
  STORE=$(grep '^storeFile=' android/key.properties | cut -d= -f2-)
  if [ -f "$STORE" ]; then
    echo "OK: keystore encontrado en $STORE"
  else
    echo "FALTA EL KEYSTORE en: $STORE"
    echo "Deberia estar en ~/Documents/lmb10_archivo_final_*/play_store_lmb10/"
    exit 1
  fi
else
  echo "NO existe android/key.properties. Restauralo de:"
  ls -d ~/Documents/lmb10_archivo_final_*/play_store_lmb10/ 2>/dev/null || true
  exit 1
fi

echo
echo "### BUILD AAB"
flutter build appbundle --release 2>&1 | tail -15

echo
ls -la build/app/outputs/bundle/release/app-release.aab
EOF
