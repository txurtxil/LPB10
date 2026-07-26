#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/main.dart backups_widget/main.dart.bak_$TS
echo "[i] Backup en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

if "reconcileOpenSession(" in s and "static Future<void> reconcileOpenSession" in s:
    sys.exit("[skip] el metodo ya esta definido, nada que hacer")

# ---- 1. startSession: no bloquear + definir reconcileOpenSession ----
old_start = '''  static Future<void> startSession(double soc) async {
    final sessions = await load();
    // Evita duplicar si ya hay una sesion abierta (sin endTs)
    if (sessions.isNotEmpty && sessions.last.endTs == null) return;
    sessions.add(ChargeSession(startTs: DateTime.now().millisecondsSinceEpoch, startSoc: soc));
    await _saveAll(sessions);
  }'''
new_start = '''  static Future<void> startSession(double soc) async {
    final sessions = await load();
    // Si quedo una sesion abierta (p. ej. el TCU se durmio y no vimos el fin),
    // se cierra con su ultimo SoC conocido ANTES de abrir la nueva. Antes esto
    // bloqueaba y descartaba en silencio todas las cargas siguientes.
    if (sessions.isNotEmpty && sessions.last.endTs == null) {
      final open = sessions.last;
      if (soc - open.startSoc >= 1.0) {
        open.endTs = DateTime.now().millisecondsSinceEpoch;
        open.endSoc = soc;
        await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, soc);
      } else {
        sessions.removeLast();
      }
      await _saveAll(sessions);
    }
    final fresh = await load();
    fresh.add(ChargeSession(startTs: DateTime.now().millisecondsSinceEpoch, startSoc: soc));
    await _saveAll(fresh);
  }

  /// Cierra una sesion huerfana (quedo abierta porque el sueno del TCU impidio
  /// ver el fin de la carga). Se llama en CADA refresco, antes de la deteccion
  /// normal. Cierra por evidencia; el tiempo es solo red de seguridad.
  static Future<void> reconcileOpenSession({
    required bool isPluggedIn,
    required bool chargeCompleted,
    required double? currentSoc,
  }) async {
    final sessions = await load();
    if (sessions.isEmpty || sessions.last.endTs != null) return;
    final open = sessions.last;
    final ageH =
        (DateTime.now().millisecondsSinceEpoch - open.startTs) / 3600000.0;
    final shouldClose = !isPluggedIn || chargeCompleted || ageH > 12.0;
    if (!shouldClose) return;
    final endSoc = currentSoc ?? open.startSoc;
    if (endSoc - open.startSoc >= 1.0) {
      open.endTs = DateTime.now().millisecondsSinceEpoch;
      open.endSoc = endSoc;
      await _saveAll(sessions);
      await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, endSoc);
    } else {
      sessions.removeLast();
      await _saveAll(sessions);
    }
  }'''
if s.count(old_start) != 1:
    sys.exit("ABORT: ancla startSession x%d" % s.count(old_start))
s = s.replace(old_start, new_start, 1)

# ---- 2. Llamada en BACKGROUND ----
old_bg = '''  final soc = status.preciseSoc ?? status.soc?.toDouble();
  if (soc != null) {
    if (!wasCharging && status.isCharging) {
      await ChargeHistoryStore.startSession(soc);
    } else if (wasCharging && !status.isCharging) {
      await ChargeHistoryStore.endSession(soc);
    }'''
new_bg = '''  final soc = status.preciseSoc ?? status.soc?.toDouble();
  await ChargeHistoryStore.reconcileOpenSession(
    isPluggedIn: status.isPluggedIn,
    chargeCompleted: status.chargeCompleted == true,
    currentSoc: soc,
  );
  if (soc != null) {
    if (!wasCharging && status.isCharging) {
      await ChargeHistoryStore.startSession(soc);
    } else if (wasCharging && !status.isCharging) {
      await ChargeHistoryStore.endSession(soc);
    }'''
if s.count(old_bg) != 1:
    sys.exit("ABORT: ancla background x%d" % s.count(old_bg))
s = s.replace(old_bg, new_bg, 1)

io.open(d, 'w', encoding='utf-8').write(s)
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("[dry] %s diff=%d" % (n, s.count(op)-s.count(cl)))
print("[dry] definicion:", s.count("static Future<void> reconcileOpenSession"))
print("[dry] llamadas totales:", s.count("await ChargeHistoryStore.reconcileOpenSession"))
print("[dry] OK")
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance preservado')
"

echo "[i] Dry-run OK. Aplicando..."
cp /tmp/pruebatest/main.dart lib/main.dart

echo "[i] Verificacion final:"
echo -n "  definicion (debe ser 1): "; grep -c "static Future<void> reconcileOpenSession" lib/main.dart
echo -n "  llamadas totales (debe ser 2): "; grep -c "await ChargeHistoryStore.reconcileOpenSession" lib/main.dart
echo -n "  startSession arreglado: "; grep -c "bloqueaba y descartaba" lib/main.dart
echo -n "  bug \$ (debe ser 0): "; grep -c '\\\$' lib/main.dart || true
