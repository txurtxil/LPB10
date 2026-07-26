#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

# /tmp se vacia entre sesiones: si el fichero no existe, release_apk.sh usa
# notas por defecto OBSOLETAS sin fallar. Se crea aqui para asegurarlo.
cat > /tmp/notas.md << 'NOTASEOF'
## v3.60.3 — Arreglos de Android Auto

### Temperatura de la batería
El coche no reporta `minBatteryTemp` de forma continua (TCU dormido o sin
carga). Antes, cada lectura sin ese campo **machacaba el último valor bueno**
con una cadena vacía, y la temperatura aparecía y desaparecía.
Ahora el dato solo se sobrescribe cuando llega de verdad, y la pantalla del
coche indica la antigüedad de la lectura (`18 °C (hace 40 min)`).

### Medias de consumo por día
Las barras diarias se calculaban sobre el *ciclo actual* (desde la última
recarga). Cada carga reiniciaba el ciclo y borraba el histórico: por eso solo
se veían los días desde el último enchufe y al cargar quedaba el día en curso.
Ahora se calculan sobre el histórico permanente completo, limitadas a los 7
últimos días.

Añadida la fila **Últimos 7 días**, independiente del ciclo, para que la
pantalla siga dando una cifra útil justo después de recargar (que es cuando el
ciclo aún no tiene datos suficientes).

### Navegación a cargadores
`startCarApp(ACTION_NAVIGATE)` solo admite dos formatos de URI: `geo:lat,lon`
o `geo:0,0?q=...`. Se estaba enviando un híbrido de los dos, que algunos hosts
descartan **en silencio, sin lanzar excepción** — de ahí que al pulsar un
cargador no ocurriera nada. Cambiado al formato de búsqueda documentado, con
reintento a `geo:lat,lon` y trazas en el log del coche.

> Pendiente de verificar en el head unit real.
NOTASEOF

echo "### NOTAS PREPARADAS"
wc -l /tmp/notas.md

echo
echo "### ESTADO GIT ANTES"
git status --short
git log --oneline -2

echo
echo "### RELEASE"
bash release_apk.sh 3.60.3 /tmp/notas.md "Android Auto: temperatura de bateria, medias por dia y navegacion a cargadores"

echo
echo "### ESTADO GIT DESPUES"
git log --oneline -2
grep -n "^version:" pubspec.yaml
grep -rn "kDisplayVersion" lib/about_screen.dart | head -3
