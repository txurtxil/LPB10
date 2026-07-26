#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
O=/tmp/ctx_361b.txt
{
echo "### 1. Quien llama a buildEfficiencyTicket (el nickname)"
grep -rn "buildEfficiencyTicket\|nickname" lib/ticket_screen.dart lib/main.dart 2>/dev/null

echo; echo "### 2. ticket_screen.dart: de donde saca el nickname"
grep -rniE "nickname\|user_name\|userName\|ownerName\|deriveSession\|payload\|token" lib/ticket_screen.dart 2>/dev/null

echo; echo "### 3. ticket_screen.dart cabecera (1,60)"
sed -n '1,60p' lib/ticket_screen.dart

echo; echo "### 4. _goToLogin y como arranca SplashScreen (para insertar gate)"
sed -n '600,614p' lib/main.dart

echo; echo "### 5. about_screen: import de l10n y disclaimerText"
grep -n "disclaimerText\|_kofiUrl\|_releasesUrl\|supportProjectLabel\|buyMeACoffee" lib/about_screen.dart

echo; echo "### 6. Ya existe algun flag de 'aceptado'?"
grep -rniE "accepted\|onboard\|welcome\|firstRun\|first_run\|disclaimer_ok" lib/*.dart 2>/dev/null | head
} > "$O" 2>&1
wc -l "$O"; echo "-> adjunta $O"
