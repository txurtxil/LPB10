#!/bin/bash
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz"; exit 1; }
cp lib/main.dart backups_widget/main.dart.bak_fixnav 2>/dev/null || true
cp android/app/src/main/AndroidManifest.xml backups_widget/AndroidManifest.xml.bak_fixnav 2>/dev/null || true

# 1) Declarar los esquemas de navegacion en el manifest (queries)
python3 << 'PYEOF'
import sys
p = 'android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf-8').read()
if '<data android:scheme="geo" />' in s:
    print("OK  queries ya presentes (nada que hacer)")
else:
    anchor = "<manifest"
    # insertar bloque <queries> justo despues de la etiqueta <manifest ...>
    import re
    m = re.search(r'<manifest[^>]*>', s)
    if not m:
        print(f"ERROR: no encuentro <manifest>"); sys.exit(1)
    queries = '''
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="geo" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
    </queries>'''
    s = s[:m.end()] + queries + s[m.end():]
    open(p,'w',encoding='utf-8').write(s)
    print("OK  manifest: <queries> para navegacion")
PYEOF

# 2) Simplificar _navigateTo: lanzar Google Maps web directo (sin canLaunchUrl)
python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
old = """    final uris = [
      Uri.parse('google.navigation:q=${c.lat},${c.lon}'),
      Uri.parse('geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}(${Uri.encodeComponent(c.name)})'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lon}'),
    ];
    for (final u in uris) {
      if (await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es ? 'No se pudo abrir la navegacion' : 'Could not open navigation')));
    }"""
new = """    // Google Maps web/app: el esquema https siempre resuelve si hay navegador
    // o Maps. Intentamos primero geo: (app de mapas), luego el enlace web.
    final geo = Uri.parse('geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}(${Uri.encodeComponent(c.name)})');
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lon}');
    try {
      final okGeo = await launchUrl(geo, mode: LaunchMode.externalApplication);
      if (okGeo) return;
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es ? 'No se pudo abrir la navegacion' : 'Could not open navigation')));
      }
    }"""
if s.count(old)!=1:
    print(f"ERROR nav: ancla x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  _navigateTo: lanza directo sin canLaunchUrl")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
