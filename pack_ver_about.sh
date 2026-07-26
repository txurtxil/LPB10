#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

TS=$(date +%Y%m%d_%H%M%S)
mkdir -p backups_widget
cp lib/about_screen.dart "backups_widget/about_screen.dart.bak_$TS"

rm -rf /tmp/pruebatest && mkdir -p /tmp/pruebatest/lib
cp lib/about_screen.dart /tmp/pruebatest/lib/

python3 - << 'PYEOF'
import sys
p='/tmp/pruebatest/lib/about_screen.dart'
s=open(p,encoding='utf-8').read()
errors=[]
def rep(old,new,tag):
    global s
    if s.count(old)!=1: errors.append('ANCLA %s x%d'%(tag,s.count(old))); return
    s=s.replace(old,new); print('  ok:',tag)

# 1. constante de version (nombre propio, NO kAppVersion de Leapmotor)
rep("  static const _releasesUrl = 'https://github.com/txurtxil/LPB10/releases';",
"""  // Version visible de la app. La actualiza release_apk.sh en cada release.
  static const String kDisplayVersion = '3.60.2';
  static const _releasesUrl = 'https://github.com/txurtxil/LPB10/releases';""",
'const')

# 2. LMB10 -> Row con version a la derecha
rep("""            const Text('LMB10', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),""",
"""            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: const [
                Text('LMB10', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Text('v$kDisplayVersion', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),""",
'row')

if errors:
    print('\n=== FALLOS ==='); [print(' -',e) for e in errors]; sys.exit(1)
open(p,'w',encoding='utf-8').write(s)
print('\nOK en pruebatest')
PYEOF

echo; echo "=== balance parentesis/llaves ==="
for ch in '{' '}' '(' ')'; do
  a=$(grep -o -- "$ch" lib/about_screen.dart|wc -l)
  b=$(grep -o -- "$ch" /tmp/pruebatest/lib/about_screen.dart|wc -l)
  printf '%s %3d -> %3d (%+d)\n' "$ch" "$a" "$b" "$((b-a))"
done

echo; echo "=== analyze ==="
cp /tmp/pruebatest/lib/about_screen.dart lib/
flutter analyze lib/about_screen.dart 2>&1 | tail -12
