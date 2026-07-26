#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
{
echo "=== Contexto de user_name (130-160) ==="
sed -n '130,160p' lib/leapmotor_engine.dart
echo; echo "=== Donde se usa ese nombre ==="
grep -rniE "userName|user_name|\.name\b|ownerName" lib/ticket_printer.dart lib/ticket_screen.dart lib/main.dart 2>/dev/null | head -20
} > /tmp/ver_username.txt 2>&1
cat /tmp/ver_username.txt
