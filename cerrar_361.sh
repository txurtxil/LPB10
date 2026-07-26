#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

# 1. Corregir version en pruebatest (que ya tiene los 5 parches de codigo)
python3 - << 'PYEOF'
p='/tmp/pruebatest/pubspec.yaml'
s=open(p,encoding='utf-8').read()
old='version: 3.60.0+124'
if s.count(old)!=1:
    print('ABORTO: no encuentro', old); raise SystemExit(1)
open(p,'w',encoding='utf-8').write(s.replace(old,'version: 3.60.1+125'))
print('ok version -> 3.60.1+125')
PYEOF

# 2. Copiar a ~/LP10
cp /tmp/pruebatest/lib/main.dart lib/
cp /tmp/pruebatest/lib/about_screen.dart lib/
cp /tmp/pruebatest/lib/ticket_screen.dart lib/
cp /tmp/pruebatest/pubspec.yaml .

# 3. Verificar
echo; echo "=== version ==="
grep -n "^version:" pubspec.yaml
echo; echo "=== welcome_screen existe? ==="
ls -la lib/welcome_screen.dart
echo; echo "=== ticket sin nombre? (debe salir la version const) ==="
grep -n "TicketScreen(" lib/main.dart
echo; echo "=== gate de bienvenida enganchado? ==="
grep -n "welcomeAccepted\|WelcomeScreen" lib/main.dart
echo; echo "=== kofi fuera? (debe salir vacio) ==="
grep -n "kofi\|ko-fi\|_kofiUrl\|buyMeACoffee" lib/about_screen.dart || echo "LIMPIO"
echo; echo "=== interpolacion rota ==="
grep -c '\\\$' lib/*.dart | grep -v ':0' || echo "0 - limpio"

echo; echo "LISTO. Ahora compila."
