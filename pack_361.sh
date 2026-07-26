#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

TS=$(date +%Y%m%d_%H%M%S)
BK=backups_widget; mkdir -p "$BK"
for f in lib/main.dart lib/ticket_screen.dart lib/about_screen.dart pubspec.yaml; do
  cp "$f" "$BK/$(basename $f).bak_$TS"
done
echo "Backups en $BK/*.bak_$TS"

rm -rf /tmp/pruebatest && mkdir -p /tmp/pruebatest/lib
cp lib/main.dart lib/ticket_screen.dart lib/about_screen.dart /tmp/pruebatest/lib/
cp pubspec.yaml /tmp/pruebatest/

python3 - << 'PYEOF'
import sys
BASE='/tmp/pruebatest'
errors=[]
def rd(p): return open(BASE+p, encoding='utf-8').read()
def wr(p,s): open(BASE+p,'w',encoding='utf-8').write(s)
def rep(s,old,new,tag):
    n=s.count(old)
    if n!=1: errors.append('ANCLA %s x%d'%(tag,n)); return s
    print('  ok:',tag); return s.replace(old,new)
def add_imports(s,imps,tag):
    lines=s.split('\n'); idx=[i for i,l in enumerate(lines) if l.startswith('import ')]
    at=idx[-1]+1
    for k,imp in enumerate(imps):
        if imp in s: continue
        lines.insert(at+k,imp)
    print('  ok imports:',tag); return '\n'.join(lines)

# --- 1. Nombre fuera del ticket ---
p='/lib/main.dart'; s=rd(p)
s=rep(s,
"builder: (_) => TicketScreen(nickname: widget.vehicle.nickName),",
"builder: (_) => const TicketScreen(),",
'ticket.nombre')

# --- 2. Gate de bienvenida en SplashScreen ---
s=rep(s,
"""  Future<void> _tryRestore() async {
    if (!await hasClientCert()) {""",
"""  Future<void> _tryRestore() async {
    if (!await welcomeAccepted()) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WelcomeScreen(
              onAccept: () => Navigator.of(context).pop())));
    }
    if (!await hasClientCert()) {""",
'splash.gate')
s=add_imports(s,["import 'welcome_screen.dart';"],'main')
wr(p,s)

# --- 3. Ticket screen: nickname opcional a null-safe (ya lo es, solo quitar uso) ---
# nickname sigue existiendo como parametro opcional; no se pasa => null => sin nombre.
# No hace falta tocar ticket_screen.dart ni ticket_printer.dart.

# --- 4. about_screen: quitar kofi, poner autismo ---
p='/lib/about_screen.dart'; s=rd(p)
s=rep(s,
"  static const _kofiUrl = 'https://ko-fi.com/txurtxil';",
"  static const _autismUrl = 'https://es.wikipedia.org/wiki/Trastornos_del_espectro_autista';",
'about.url')
s=rep(s,
"""            Text(AppLocalizations.of(context)!.supportProjectLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.coffee),
              label: Text(AppLocalizations.of(context)!.buyMeACoffeeButton),
              onPressed: () => launchUrl(Uri.parse(_kofiUrl), mode: LaunchMode.externalApplication),
            ),""",
"""            Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Sobre el autismo'
                    : 'About autism',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'Esta app se desarrolla en parte para apoyar un proyecto personal sobre autismo. El autismo es una forma distinta de percibir el mundo, no una enfermedad. Comprenderlo y respetarlo ayuda a muchas personas y sus familias.'
                  : 'This app is developed partly to support a personal project about autism. Autism is a different way of perceiving the world, not an illness. Understanding and respecting it helps many people and their families.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => launchUrl(Uri.parse(_autismUrl), mode: LaunchMode.externalApplication),
              child: Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Que es el autismo (Wikipedia)'
                    : 'What is autism (Wikipedia)',
                style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline, fontSize: 13),
              ),
            ),""",
'about.autismo')
wr(p,s)

# --- 5. version ---
p='/pubspec.yaml'; s=rd(p)
s=rep(s,'version: 3.60.0+123','version: 3.60.1+124','version')
wr(p,s)

if errors:
    print('\n=== FALLOS ==='); [print(' -',e) for e in errors]; sys.exit(1)
print('\nParches OK en /tmp/pruebatest')
PYEOF

echo; echo "=== BALANCE (main.dart puede dar +/- por strings) ==="
for f in lib/main.dart lib/about_screen.dart; do
  for ch in '{' '}' '(' ')'; do
    a=$(grep -o -- "$ch" "$f"|wc -l); b=$(grep -o -- "$ch" "/tmp/pruebatest/$f"|wc -l)
    printf '%-26s %s %4d -> %4d (%+d)\n' "$f" "$ch" "$a" "$b" "$((b-a))"
  done
done

echo; echo "=== APLICANDO ==="
cp /tmp/pruebatest/lib/*.dart lib/
cp /tmp/pruebatest/pubspec.yaml .
echo "Comprobacion interpolacion rota:"
grep -c '\\\$' lib/*.dart | grep -v ':0' || echo "0 - limpio"
echo; echo "PACK 3.60.1 APLICADO. Compila."
