#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
O=/tmp/buscar_nombre.txt
{
echo "=== 1. El nombre en el codigo ==="
grep -rniE "Barrientos|Juan.?Carlos|Dominguez" lib/ assets/ 2>/dev/null

echo; echo "=== 2. Datos de ejemplo del ticket ==="
grep -rniE "17/07|13,2|14,2|14,8|480 km|108|demo|ejemplo|sample|placeholder|mock" lib/ticket_printer.dart lib/ticket_screen.dart 2>/dev/null

echo; echo "=== 3. De donde sale el nombre en el ticket ==="
grep -rniE "ownerName|userName|nombre|driverName|fullName|accountName" lib/ticket_printer.dart lib/ticket_screen.dart lib/leapmotor_engine.dart 2>/dev/null

echo; echo "=== 4. Otros nombres/emails/telefonos hardcodeados ==="
grep -rniE "@gmail|@hotmail|@outlook|\+34[0-9]|[0-9]{9}" lib/ 2>/dev/null | grep -viE "http|version|comment|//" | head -20
} > "$O" 2>&1
cat "$O"
echo; echo "-> /tmp/buscar_nombre.txt"
