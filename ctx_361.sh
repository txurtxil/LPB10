#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
O=/tmp/ctx_361.txt
{
echo "### user_name: contexto 130-160"
sed -n '130,160p' lib/leapmotor_engine.dart
echo; echo "### donde se pinta el nombre en el ticket"
grep -rniE "userName|user_name|segments|ownerName|\bname\b" lib/ticket_printer.dart lib/ticket_screen.dart 2>/dev/null
echo; echo "### ticket_printer.dart: cabecera (1,50)"
sed -n '1,50p' lib/ticket_printer.dart
echo; echo "### pantalla de inicio: donde va el texto actual"
echo "(dame el nombre del fichero de la pantalla de primer arranque/disclaimer si ya existe)"
grep -rniE "disclaimer|no oficial|not official|aceptar|acepto|primer arranque" lib/*.dart 2>/dev/null | head
echo; echo "### SplashScreen 555-614"
sed -n '555,614p' lib/main.dart
} > "$O" 2>&1
wc -l "$O"; echo "-> adjunta $O"
