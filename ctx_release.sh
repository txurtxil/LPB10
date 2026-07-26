#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
O=/tmp/ctx_release.txt
{
echo "### release_apk.sh entero"
cat release_apk.sh
} > "$O" 2>&1
wc -l "$O"; echo "-> adjunta $O"
