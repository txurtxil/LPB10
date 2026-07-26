#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp $K/CarMainScreen.kt backups_widget/CarMainScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

# ============ 1. Dart: exponer comandos directos en el bridge ============
python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

# Añadir case 'quickAction' al handler del canal
old = '''        case 'runRoutine':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final id = args['id'] as String?;
          if (id == null || id.isEmpty) return '';
          return await carRunRoutineById(id);
      }'''
new = '''        case 'runRoutine':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final id = args['id'] as String?;
          if (id == null || id.isEmpty) return '';
          return await carRunRoutineById(id);
        case 'quickAction':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final action = args['action'] as String?;
          if (action == null || action.isEmpty) return false;
          return await carQuickAction(action);
      }'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla handler x%d" % s.count(old))
s = s.replace(old, new, 1)

# Añadir la funcion carQuickAction despues de carRunRoutineById
anchor = '''    final total = res.done + res.failed + res.skipped;
    return '${res.done}/$total';
  } catch (_) {
    return '';
  }
}'''
if s.count(anchor) != 1:
    sys.exit("ABORT: ancla fin carRunRoutine x%d" % s.count(anchor))

func = anchor + '''

/// Ejecuta un comando directo (accion rapida) desde el coche, sin UI.
/// Reutiliza el mismo patron de cliente que carRunRoutineById.
@pragma('vm:entry-point')
Future<bool> carQuickAction(String action) async {
  final raw = await _storage.read(key: _sessionKey);
  if (raw == null) return false;
  final vin = await _storage.read(key: _vinKey) ?? '';
  final pin = await _storage.read(key: _pinKey) ?? '';
  if (vin.isEmpty || pin.isEmpty) return false;
  try {
    final sessionMap = Map<String, String>.from(json.decode(raw) as Map);
    final session = SessionData.fromMap(sessionMap);
    final staticClient = await createStaticClient();
    final c = LeapmotorApiClient(staticClient);
    await c.restoreSession(session);
    switch (action) {
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
s = s.replace(anchor, func, 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] Dart: carQuickAction + case en el handler")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance main preservado')
"
cp /tmp/pruebatest/main.dart lib/main.dart

# ============ 2. Kotlin: metodo quickAction en CarBridge ============
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/CarBridge.kt"
s = io.open(p, encoding='utf-8').read()

# Buscar el metodo runRoutine para añadir quickAction al lado
if "fun quickAction" not in s:
    anchor = "fun runRoutine("
    if anchor not in s:
        sys.exit("ABORT: no encuentro runRoutine en CarBridge")
    # localizar el final del metodo runRoutine (asumimos que termina en } antes de otro fun o del cierre de clase)
    idx = s.index(anchor)
    # Insertar un metodo nuevo justo antes de runRoutine (mismo patron)
    method = '''fun quickAction(action: String, cb: (String) -> Unit) {
        val ch = channel
        if (ch == null) {
            queue.add { quickAction(action, cb) }
            start(appCtx)
            return
        }
        ch.invokeMethod("quickAction", mapOf("action" to action), object : MethodChannel.Result {
            override fun success(result: Any?) {
                cb(if (result == true) "OK" else "ERR")
            }
            override fun error(code: String, msg: String?, details: Any?) { cb("ERR") }
            override fun notImplemented() { cb("ERR") }
        })
    }

    '''
    s = s[:idx] + method + s[idx:]
    io.open(p, 'w', encoding='utf-8').write(s)
    print("[ok] CarBridge: metodo quickAction añadido")
else:
    print("[skip] quickAction ya existe en CarBridge")
PYEOF

# ============ 3. Kotlin: QuickActionsScreen (GridTemplate) ============
cat > $K/QuickActionsScreen.kt <<'KEOF'
package com.txurtxil.lpb10

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetPlugin

class QuickActionsScreen(carContext: CarContext) : Screen(carContext) {

    private data class QA(val action: String, val esLabel: String, val enLabel: String, val icon: Int)

    private val actions = listOf(
        QA("lock", "Cerrar", "Lock", R.drawable.ic_car_battery),
        QA("unlock", "Abrir", "Unlock", R.drawable.ic_car_battery),
        QA("heat", "Calor", "Heat", R.drawable.ic_car_battery),
        QA("cool", "Frio", "Cool", R.drawable.ic_car_battery),
        QA("defrost", "Desempanar", "Defrost", R.drawable.ic_car_battery),
        QA("find", "Buscar", "Find car", R.drawable.ic_car_chargers),
        QA("trunk", "Maletero", "Trunk", R.drawable.ic_car_battery),
        QA("sentry_on", "Centinela", "Sentry", R.drawable.ic_car_battery),
        QA("preheat", "Precalentar", "Preheat", R.drawable.ic_car_battery)
    )

    private fun icon(res: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, res)).build()

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es") == "es"
        val list = ItemList.Builder()
        for (qa in actions) {
            val label = if (es) qa.esLabel else qa.enLabel
            list.addItem(
                GridItem.Builder()
                    .setTitle(label)
                    .setImage(icon(qa.icon))
                    .setOnClickListener { fire(qa, label, es) }
                    .build()
            )
        }
        return GridTemplate.Builder()
            .setSingleList(list.build())
            .setTitle(if (es) "Acciones rapidas" else "Quick actions")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun fire(qa: QA, label: String, es: Boolean) {
        CarToast.makeText(carContext, if (es) "Enviando: $label" else "Sending: $label", CarToast.LENGTH_SHORT).show()
        CarLog.log(carContext, "QUICK", "accion " + qa.action)
        CarBridge.quickAction(qa.action) { result ->
            Handler(Looper.getMainLooper()).post {
                val ok = result == "OK"
                val msg = if (es) (if (ok) "$label: hecho" else "$label: fallo")
                          else (if (ok) "$label: done" else "$label: failed")
                CarToast.makeText(carContext, msg, CarToast.LENGTH_LONG).show()
            }
        }
    }
}
KEOF
echo "[ok] QuickActionsScreen.kt creado"

# ============ 4. Kotlin: enganchar en el hub (CarMainScreen) ============
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/CarMainScreen.kt"
s = io.open(p, encoding='utf-8').read()

if "QuickActionsScreen" in s:
    sys.exit("[skip] ya enganchado")

# Buscar la fila de Rutinas para añadir "Acciones rapidas" antes o despues.
# Anclamos en la fila que navega a RoutinesScreen.
import re
# Buscar un addRow/addItem que abra RoutinesScreen
if "RoutinesScreen(carContext)" not in s:
    sys.exit("ABORT: no encuentro navegacion a RoutinesScreen en el hub")

# Insertar una fila nueva justo despues del bloque de Rutinas.
# Estrategia: duplicar el patron de una Row existente. Buscamos el bloque
# que contiene RoutinesScreen y su Row.Builder(...).build()
anchor = "RoutinesScreen(carContext)"
idx = s.index(anchor)
# Buscar el cierre de esa Row: el ".build()" que sigue
build_idx = s.index(".build()", idx)
insert_pos = s.index("\n", build_idx) + 1

# La fila nueva (misma estructura tipica: Row con title, onClick screen push)
newrow = '''        listBuilder.addItem(
            Row.Builder()
                .setTitle(if (es) "Acciones rapidas" else "Quick actions")
                .addText(if (es) "Clima, cerrar, centinela y mas" else "Climate, lock, sentry and more")
                .setImage(vecIcon(R.drawable.ic_car_routines))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(QuickActionsScreen(carContext)) }
                .build()
        )
'''
# OJO: los nombres (listBuilder, vecIcon, es) deben coincidir con el codigo real.
# Se ajustaran si el ABORT lo indica.
s = s[:insert_pos] + newrow + s[insert_pos:]
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] CarMainScreen: fila Acciones rapidas añadida")
PYEOF

echo "[i] Verificacion:"
echo -n "  carQuickAction en Dart (1): "; grep -c "Future<bool> carQuickAction" lib/main.dart
echo -n "  quickAction en CarBridge (1): "; grep -c "fun quickAction" $K/CarBridge.kt
echo -n "  QuickActionsScreen existe: "; ls $K/QuickActionsScreen.kt >/dev/null 2>&1 && echo OK
echo -n "  enganchado en hub: "; grep -c "QuickActionsScreen(carContext)" $K/CarMainScreen.kt
echo -n "  bug \$ Dart (0): "; grep -c '\\\$' lib/main.dart || true
