cd ~/LP10
grep '^version:' pubspec.yaml
flutter build appbundle --release 2>&1 | tee /tmp/build_aab.txt | tail -12
ls -lh build/app/outputs/bundle/release/*.aab
