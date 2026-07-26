#!/usr/bin/env bash
set -euo pipefail
OUT=/tmp/carlog2_$(date +%H%M%S).txt

echo "### VERSION INSTALADA EN EL MOVIL"
adb shell dumpsys package com.txurtxil.lpb10 | grep -E "versionName|versionCode" | head -2 || true

echo
echo "### INTENTO 1: ruta correcta (app_flutter)"
adb shell "run-as com.txurtxil.lpb10 cat app_flutter/lmb10_history/carlog.txt" 2>&1 \
  | tail -80 > "$OUT" || true

echo "### INTENTO 2: logcat"
adb logcat -d 2>/dev/null | grep -i "CONSUMO\|NAV " | tail -40 >> "$OUT" || true

echo
echo "--- lineas CONSUMO encontradas:"
grep -n "CONSUMO" "$OUT" || echo "(ninguna)"
echo
echo "Escrito: $OUT"
wc -c "$OUT"
