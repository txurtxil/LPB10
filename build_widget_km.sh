#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
LOG=/tmp/build_wkm_$(date +%H%M%S).log

echo "### ANALYZE"
flutter analyze lib/widget_chart.dart 2>&1 | grep -E "error •" | head -10 || echo "(limpio)"

echo
echo "### BUILD"
flutter build apk --release 2>&1 | tee "$LOG" | tail -10

echo
echo "### ERRORES"
grep -E "^e: |Error:|error •" "$LOG" | head -10 || echo "(ninguno)"
