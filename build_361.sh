#!/usr/bin/env bash
set -uo pipefail
cd ~/LP10
flutter pub get
flutter build apk --release 2>&1 | tail -25
