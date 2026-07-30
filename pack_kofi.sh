set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/about_screen.dart "backups_widget/about_screen.dart.bak_$TS"
echo "Backup: backups_widget/about_screen.dart.bak_$TS"

python3 - << 'PYEOF'
import sys
p = 'lib/about_screen.dart'
s = open(p, encoding='utf-8').read()
antes = (s.count('('), s.count(')'), s.count('{'), s.count('}'))

def rep(old, new, tag):
    global s
    n = s.count(old)
    if n != 1:
        print("ABORTA %s: %d ocurrencias" % (tag, n)); sys.exit(1)
    s = s.replace(old, new)

rep("""  static const _autismUrl = 'https://es.wikipedia.org/wiki/Trastornos_del_espectro_autista';""",
"""  static const _autismUrl = 'https://es.wikipedia.org/wiki/Trastornos_del_espectro_autista';
  static const _kofiUrl = 'https://ko-fi.com/txurtxil';""", 'url')

# Column a pelo: al anadir contenido desbordaria en pantallas pequenas.
# SingleChildScrollView acepta el mismo padding, asi que es cambiar la palabra.
rep("""      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(""",
"""      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(""", 'scroll')

rep("""            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.disclaimerText,""",
"""            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Apoyar el desarrollo'
                    : 'Support development',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'LMB10 es gratis, de codigo abierto y no tiene publicidad ni rastreadores. Si te resulta util y te apetece invitarme a un cafe, se agradece mucho. Es completamente opcional: no desbloquea nada dentro de la app ni da soporte prioritario.'
                  : 'LMB10 is free, open source, with no ads or trackers. If it is useful to you and you feel like buying me a coffee, it is much appreciated. It is entirely optional: it unlocks nothing inside the app and buys no priority support.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(_kofiUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.coffee_outlined, size: 18),
              label: const Text('ko-fi.com/txurtxil'),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.disclaimerText,""", 'bloque-kofi')

open(p, 'w', encoding='utf-8').write(s)
d = (s.count('('), s.count(')'), s.count('{'), s.count('}'))
print("  parentesis %d/%d -> %d/%d   llaves %d/%d -> %d/%d" %
      (antes[0], antes[1], d[0], d[1], antes[2], antes[3], d[2], d[3]))
if d[0] != d[1] or d[2] != d[3]:
    print("ABORTA: descuadre"); sys.exit(1)
print("OK")
PYEOF

echo "--- verificaciones ---"
echo -n "kofiUrl: "; grep -c '_kofiUrl' lib/about_screen.dart
echo -n "Padding a pelo (debe 0): "; grep -c 'body: Padding(' lib/about_screen.dart || true
echo
echo "--- analyze ---"
flutter analyze 2>&1 | grep '• lib/about' || echo "(about_screen limpio)"
