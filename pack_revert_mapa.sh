#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

# Restaurar ChargersScreen desde el backup previo al Bonus 2
BAK=$(ls -t backups_widget/ChargersScreen.kt.bak_* | grep -v "$TS" | head -1)
echo "[i] Restaurando desde: $BAK"
cp "$BAK" $K/ChargersScreen.kt

echo "[i] Verificacion (debe volver a ListTemplate, sin PlaceListMap):"
echo -n "  ListTemplate (>=1): "; grep -c "ListTemplate" $K/ChargersScreen.kt
echo -n "  PlaceListMapTemplate (debe ser 0): "; grep -c "PlaceListMapTemplate" $K/ChargersScreen.kt || true
