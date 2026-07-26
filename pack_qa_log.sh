#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/main.dart backups_widget/main.dart.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
d = "lib/main.dart"
s = io.open(d, encoding='utf-8').read()

# Añadir logging del error real en carQuickAction para diagnosticar
old = '''    switch (action) {
      case 'lock':          await c.lockVehicle(vin, pin); break;
      case 'unlock':        await c.unlockVehicle(vin, pin); break;
      case 'heat':          await c.quickHeat(vin, pin); break;
      case 'cool':          await c.quickCool(vin, pin); break;
      case 'defrost':       await c.windshieldDefrost(vin, pin); break;
      case 'find':          await c.findVehicle(vin, pin); break;
      case 'trunk':         await c.openTrunk(vin, pin); break;
      case 'sentry_on':     await c.sentryModeOn(vin, pin); break;
      case 'sentry_off':    await c.sentryModeOff(vin, pin); break;
      case 'preheat':       await c.batteryPreheatOn(vin, pin); break;
      default: return false;
    }
    return true;
  } catch (_) {
    return false;
  }
}'''
new = '''    switch (action) {
      case 'lock':          await c.lockVehicle(vin, pin); break;
      case 'unlock':        await c.unlockVehicle(vin, pin); break;
      case 'heat':          await c.quickHeat(vin, pin); break;
      case 'cool':          await c.quickCool(vin, pin); break;
      case 'defrost':       await c.windshieldDefrost(vin, pin); break;
      case 'find':          await c.findVehicle(vin, pin); break;
      case 'trunk':         await c.openTrunk(vin, pin); break;
      case 'trunk_close':   await c.closeTrunk(vin, pin); break;
      case 'sentry_on':     await c.sentryModeOn(vin, pin); break;
      case 'sentry_off':    await c.sentryModeOff(vin, pin); break;
      case 'preheat':       await c.batteryPreheatOn(vin, pin); break;
      case 'preheat_off':   await c.batteryPreheatOff(vin, pin); break;
      case 'wheel_heat':    await c.steeringWheelHeatOn(vin, pin); break;
      case 'charger_unlock': await c.unlockCharger(vin, pin); break;
      default:
        await CarLogBridge.log('quickAction desconocida: $action');
        return false;
    }
    await CarLogBridge.log('quickAction OK: $action');
    return true;
  } catch (e) {
    await CarLogBridge.log('quickAction FALLO $action: $e');
    return false;
  }
}

/// Puente minimo para que carQuickAction escriba en el log del coche.
class CarLogBridge {
  static Future<void> log(String msg) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/lmb10_history/carlog.txt');
      await f.parent.create(recursive: true);
      final ts = DateTime.now().toIso8601String().substring(5, 19);
      await f.writeAsString('$ts [DART-QA] $msg\\n', mode: FileMode.append);
    } catch (_) {}
  }
}'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla switch x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] carQuickAction: logging de errores + 4 acciones nuevas")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

echo -n "  logging añadido (1): "; grep -c "quickAction FALLO" lib/main.dart
echo -n "  acciones nuevas (trunk_close): "; grep -c "trunk_close" lib/main.dart
echo -n "  bug \$ (0): "; grep -c '\\\$' lib/main.dart || true
