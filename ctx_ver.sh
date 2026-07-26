#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
O=/tmp/ctx_ver.txt
{
echo "### package_info_plus instalado?"
grep -n "package_info_plus" pubspec.yaml || echo "NO"

echo; echo "### como se muestra la version en algun sitio ya?"
grep -rniE "VERSION_NAME|packageInfo|PackageInfo|version.*3\.|3\.60|appVersion|kAppVersion" lib/*.dart | grep -viE "kAppVersion =|signInput|kAppVersion," | head -20

echo; echo "### about_screen.dart entero (ya parcheado)"
cat lib/about_screen.dart
} > "$O" 2>&1
wc -l "$O"; echo "-> adjunta $O"
