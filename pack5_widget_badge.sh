#!/bin/bash
# ============================================================================
# LMB10 - pack5_widget_badge.sh
#  1) Widget: PNG con nombre unico por render (mata el cacheo del bitmap de
#     Android que impedia ver el grafico nuevo).
#  2) Globo de mensajes: contador local. Al abrir Mensajes se marca como
#     "visto" el total actual; el globo muestra solo los llegados despues.
#     (Provisional: si hay endpoint oficial de marcar leido, lo integramos.)
# Ejecutar desde la raiz: bash pack5_widget_badge.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_pack5
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_pack5

# --- 1) Widget: nombre de PNG unico + limpiar antiguos ---
python3 << 'PYEOF'
import sys
p='lib/widget_chart.dart'
s=open(p,encoding='utf-8').read()

old="""      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/widget_chart.png');
      await file.writeAsBytes(bytes, flush: true);
      chartPath = file.path;"""
new="""      final dir = await getApplicationSupportDirectory();
      // Nombre unico por render: evita que Android reutilice el bitmap viejo.
      try {
        for (final f in dir.listSync()) {
          if (f is File && f.path.contains('/widget_chart')) {
            f.deleteSync();
          }
        }
      } catch (_) {}
      final file = File('${dir.path}/widget_chart_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);
      chartPath = file.path;"""
if s.count(old)!=1:
    print(f"ERROR widget: ancla {s.count(old)} veces"); sys.exit(1)
s=s.replace(old,new)
open(p,'w',encoding='utf-8').write(s)
print("OK  widget: PNG con nombre unico por render")
PYEOF

# --- 2) Globo local: descontar lo ya visto ---
python3 << 'PYEOF'
import sys
p='lib/main.dart'
s=open(p,encoding='utf-8').read()

old="""  Future<void> _refreshUnread() async {
    try {
      final n = await widget.client.getUnreadMessageCount();
      if (mounted) setState(() => _unreadMsgs = n);
    } catch (_) {}
  }"""
new="""  Future<void> _refreshUnread() async {
    try {
      final n = await widget.client.getUnreadMessageCount();
      final seen = int.tryParse(await _storage.read(key: 'lm_msgs_seen_v1') ?? '0') ?? 0;
      final pending = (n - seen) < 0 ? 0 : (n - seen);
      if (mounted) setState(() => _unreadMsgs = pending);
    } catch (_) {}
  }

  Future<void> _markMessagesSeen() async {
    try {
      final n = await widget.client.getUnreadMessageCount();
      await _storage.write(key: 'lm_msgs_seen_v1', value: '$n');
      if (mounted) setState(() => _unreadMsgs = 0);
    } catch (_) {}
  }"""
if s.count(old)!=1:
    print(f"ERROR badge#1: ancla {s.count(old)} veces"); sys.exit(1)
s=s.replace(old,new)

# al abrir Mensajes desde el sobre: marcar visto en vez de solo refrescar
old2="""              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(client: widget.client)));
              _refreshUnread();"""
new2="""              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(client: widget.client)));
              await _markMessagesSeen();"""
if s.count(old2)!=1:
    print(f"ERROR badge#2: ancla {s.count(old2)} veces"); sys.exit(1)
s=s.replace(old2,new2)
open(p,'w',encoding='utf-8').write(s)
print("OK  globo: contador local (baja a 0 al abrir Mensajes)")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
