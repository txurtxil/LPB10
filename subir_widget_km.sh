#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

ACTUAL=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | cut -d+ -f1)
ULT=$(gh release list --limit 30 --json tagName --jq '.[].tagName' \
      | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
echo "pubspec: $ACTUAL   ultima release: v$ULT"
MAX=$(printf '%s\n%s\n' "$ACTUAL" "$ULT" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
MA=$(echo "$MAX" | cut -d. -f1); MI=$(echo "$MAX" | cut -d. -f2); PA=$(echo "$MAX" | cut -d. -f3)
NUEVA="$MA.$MI.$((PA+1))"
echo "siguiente: v$NUEVA"
gh release view "v$NUEVA" >/dev/null 2>&1 && { echo "ABORTA: ya existe"; exit 1; }

cat > /tmp/notas.md << 'NOTASEOF'
## Kilómetros por día en el widget

El widget mostraba, por cada día, el consumo cada cien kilómetros y lo que
había costado. Faltaba el dato que une los dos y sin él la tabla parecía
contradecirse: un día a 14,2 kWh/100 costaba 0,17 € y otro a 14,8 costaba 1,10.

No era el ritmo de conducción, eran los kilómetros: nueve frente a cincuenta y
siete. Ahora aparecen en su propia columna y se entiende de un vistazo.

Para hacerles sitio desaparecen las barras por día. Ocupaban un tercio del
ancho disponible y solo daban una comparación relativa que las cifras
alineadas en columnas ya ofrecen igual de bien. El signo **>** sigue marcando
los días que superan el objetivo de consumo.

En resumen: los kWh cada 100 km dicen **cómo** conduces, los kilómetros dicen
**cuánto** usas el coche, y el importe es consecuencia de ambos.
NOTASEOF

echo
echo "### RELEASE v$NUEVA"
bash release_apk.sh "$NUEVA" /tmp/notas.md "Kilometros por dia en el widget"

echo
echo "### AAB"
flutter build appbundle --release 2>&1 | tail -6

echo
grep -n "^version:" pubspec.yaml
python3 ~/check_aab.py
echo
echo "Arrastra a Play Console:"
echo "  $HOME/LP10/build/app/outputs/bundle/release/app-release.aab"
