#!/usr/bin/env bash
set -uo pipefail
echo "### LIMPIANDO PLAY Y SERVICIOS"
adb shell pm clear com.android.vending
adb shell am force-stop com.android.vending
adb shell pm clear com.google.android.gms 2>/dev/null || echo "(gms no se pudo limpiar, normal)"
echo
echo "### ABRIENDO LA FICHA"
adb shell am start -a android.intent.action.VIEW -d "market://details?id=com.txurtxil.lpb10"
echo "Mira el movil."
