#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
echo "=== version actual ==="
grep -n "^version:" pubspec.yaml
echo; echo "=== ultimas releases/tags ==="
git tag | sort -V | tail -5
echo; echo "=== pruebatest se genero? ==="
ls -la /tmp/pruebatest/lib/*.dart 2>/dev/null | head
