#!/usr/bin/env bash
set -euo pipefail
OUT=/tmp/carlog_$(date +%H%M%S).txt
adb shell "run-as com.txurtxil.lpb10 cat files/lmb10_history/carlog.txt" 2>/dev/null \
  | tail -60 > "$OUT" || {
    echo "run-as fallo (APK release no es debuggable). Usa el visor de la app:"
    echo "  Ajustes -> Log del coche"
  }
grep -n "CONSUMO" "$OUT" || echo "(sin lineas CONSUMO todavia)"
echo "Escrito: $OUT"
