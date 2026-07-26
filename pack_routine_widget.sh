#!/bin/bash
# ============================================================================
# LMB10 - pack_routine_widget.sh  —  Favoritas + botones de rutina en el widget
#
#  1) Estrella de FAVORITAS en la pantalla Rutinas (maximo 2, persistidas en
#     lm_routines_v1). Aviso si intentas marcar una tercera.
#  2) El widget publica esas 1-2 favoritas y pinta un boton por cada una
#     DEBAJO del grafico de consumo.
#  3) Al pulsar un boton: abre la app via HomeWidgetLaunchIntent con un URI
#     lmb10://routine?id=<id>. Flutter lo recibe (widgetClicked / launch), abre
#     RoutinesScreen con autoRunId y ejecuta la rutina (via fiable, sin
#     BroadcastReceiver que ejecute comandos en el widget).
#
# Ejecutar desde la raiz: bash pack_routine_widget.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_rwidget
cp lib/routines/routine_engine.dart backups_widget/routine_engine.dart.bak_rwidget
cp lib/routines/routines_screen.dart backups_widget/routines_screen.dart.bak_rwidget
KT=android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt
LAYOUT=android/app/src/main/res/layout/battery_widget.xml
cp "$KT" backups_widget/BatteryWidgetProvider.kt.bak_rwidget
cp "$LAYOUT" backups_widget/battery_widget.xml.bak_rwidget

# ---------------------------------------------------------------------------
# 1) routine_engine.dart: campo favorite + helper de favoritas
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/routines/routine_engine.dart'
s = open(p, encoding='utf-8').read()

patches = [
 ("  bool enabled;\n\n  // Disparador programado",
  "  bool enabled;\n  bool favorite;\n\n  // Disparador programado"),
 ("    this.enabled = true,\n    this.scheduleHour,",
  "    this.enabled = true,\n    this.favorite = false,\n    this.scheduleHour,"),
 ("        'enabled': enabled,\n        'scheduleHour': scheduleHour,",
  "        'enabled': enabled,\n        'favorite': favorite,\n        'scheduleHour': scheduleHour,"),
 ("        enabled: j['enabled'] as bool? ?? true,\n        scheduleHour:",
  "        enabled: j['enabled'] as bool? ?? true,\n        favorite: j['favorite'] as bool? ?? false,\n        scheduleHour:"),
]
for a,b in patches:
    if s.count(a) != 1:
        print(f"ERROR engine: ancla x{s.count(a)}: {a[:40]}"); sys.exit(1)
    s = s.replace(a,b)

anchor = "  /// Rutinas de autonomia precargadas la primera vez."
helper = """  /// Devuelve hasta 2 rutinas marcadas como favoritas, en orden.
  static Future<List<Routine>> favorites() async {
    final all = await load();
    return all.where((r) => r.favorite).take(2).toList();
  }

  /// Rutinas de autonomia precargadas la primera vez."""
if s.count(anchor) != 1:
    print("ERROR engine: ancla helper"); sys.exit(1)
s = s.replace(anchor, helper)

open(p,'w',encoding='utf-8').write(s)
print("OK  routine_engine.dart: campo favorite + favorites()")
PYEOF

# ---------------------------------------------------------------------------
# 2) routines_screen.dart: estrella de favoritas (max 2)
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/routines/routines_screen.dart'
s = open(p, encoding='utf-8').read()

anchor_method = "  Future<void> _toggleEnabled(Routine r, bool v) async {"
method = """  Future<void> _toggleFavorite(Routine r) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (!r.favorite) {
      final count = _routines.where((x) => x.favorite).length;
      if (count >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'Maximo 2 favoritas en el widget. Quita una primero.'
                : 'Max 2 widget favorites. Remove one first.')));
        return;
      }
    }
    setState(() => r.favorite = !r.favorite);
    await RoutineStore.saveAll(_routines);
  }

  Future<void> _toggleEnabled(Routine r, bool v) async {"""
if s.count(anchor_method) != 1:
    print("ERROR screen: ancla metodo"); sys.exit(1)
s = s.replace(anchor_method, method)

anchor_row = """                Expanded(
                  child: Text(r.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (r.isScheduled)
                  Switch("""
row = """                IconButton(
                  icon: Icon(r.favorite ? Icons.star : Icons.star_border,
                      color: r.favorite ? Colors.amber : null),
                  tooltip: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Favorita del widget'
                      : 'Widget favorite',
                  onPressed: () => _toggleFavorite(r),
                ),
                Expanded(
                  child: Text(r.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (r.isScheduled)
                  Switch"""
if s.count(anchor_row) != 1:
    print("ERROR screen: ancla row"); sys.exit(1)
s = s.replace(anchor_row, row)

open(p,'w',encoding='utf-8').write(s)
print("OK  routines_screen.dart: estrella de favoritas")
PYEOF

# ---------------------------------------------------------------------------
# 3) main.dart: import + push favoritas + deep link (widgetClicked/launch)
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()

def one(a, b, label):
    global s
    if s.count(a) != 1:
        print(f"ERROR main '{label}': ancla x{s.count(a)}"); sys.exit(1)
    s = s.replace(a, b)
    print(f"OK  {label}")

one("import 'routines/routines_background.dart';",
    "import 'routines/routines_background.dart';\nimport 'routines/routine_engine.dart';",
    'import routine_engine')

one("""  } catch (_) {
    // El grafico nunca debe romper el refresco del widget
  }
  await HomeWidget.updateWidget(androidName: 'BatteryWidgetProvider');""",
    """  } catch (_) {
    // El grafico nunca debe romper el refresco del widget
  }
  try {
    final favs = await RoutineStore.favorites();
    await HomeWidget.saveWidgetData<String>('fav1_id', favs.isNotEmpty ? favs[0].id : '');
    await HomeWidget.saveWidgetData<String>('fav1_name', favs.isNotEmpty ? favs[0].name : '');
    await HomeWidget.saveWidgetData<String>('fav2_id', favs.length > 1 ? favs[1].id : '');
    await HomeWidget.saveWidgetData<String>('fav2_name', favs.length > 1 ? favs[1].name : '');
  } catch (_) {}
  await HomeWidget.updateWidget(androidName: 'BatteryWidgetProvider');""",
    'push favoritas')

one("const _storage = FlutterSecureStorage();",
    """const _storage = FlutterSecureStorage();

/// Rutina pendiente de ejecutar por pulsacion en el widget (deep link
/// lmb10://routine?id=<id>). La consume el Dashboard cuando esta listo.
String? gPendingRoutineId;
void Function()? gOnRoutinePending;
String? _routineIdFromUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != 'lmb10') return null;
  if (uri.host != 'routine' && uri.path != 'routine') return null;
  final id = uri.queryParameters['id'];
  return (id != null && id.isNotEmpty) ? id : null;
}""",
    'estado global deep link')

one("""  runApp(const LPB10App());
}""",
    """  // Deep link de rutina desde el widget (arranque en frio)
  try {
    gPendingRoutineId = _routineIdFromUri(await HomeWidget.initiallyLaunched());
  } catch (_) {}
  // Deep link de rutina con la app ya viva
  HomeWidget.widgetClicked.listen((uri) {
    final id = _routineIdFromUri(uri);
    if (id != null) {
      gPendingRoutineId = id;
      gOnRoutinePending?.call();
    }
  });
  runApp(const LPB10App());
}""",
    'main: launch + listener')

one("""    _sessionPin = widget.pin;""",
    """    _sessionPin = widget.pin;
    gOnRoutinePending = () { if (mounted) _maybeRunPendingRoutine(); };""",
    'dashboard registra callback')

one("""      setState(() { _status = status; _refreshing = false; _lastFetched = DateTime.now(); _transientError = null; });
      _refreshUnread();""",
    """      setState(() { _status = status; _refreshing = false; _lastFetched = DateTime.now(); _transientError = null; });
      _refreshUnread();
      _maybeRunPendingRoutine();""",
    'dashboard consume tras status')

one("""  Future<void> _refreshUnread() async {""",
    """  Future<void> _maybeRunPendingRoutine() async {
    final id = gPendingRoutineId;
    if (id == null) return;
    gPendingRoutineId = null;
    final pin = await _resolvePin();
    if (pin == null || pin.isEmpty) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoutinesScreen(
        client: widget.client,
        vin: widget.vehicle.vin,
        pin: pin,
        status: _status,
        autoRunId: id,
      ),
    ));
    _loadStatus();
  }

  Future<void> _refreshUnread() async {""",
    'metodo _maybeRunPendingRoutine')

open(p,'w',encoding='utf-8').write(s)
print("OK  parches main.dart aplicados")
PYEOF

# ---------------------------------------------------------------------------
# 4) Layout: 2 botones de rutina entre el grafico y "updated"
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'android/app/src/main/res/layout/battery_widget.xml'
s = open(p, encoding='utf-8').read()

anchor = """    <TextView
        android:id="@+id/widget_updated\""""
buttons = """    <LinearLayout
        android:id="@+id/widget_routines_row"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:visibility="gone"
        android:layout_marginTop="6dp">
        <Button
            android:id="@+id/widget_routine1"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginEnd="4dp"
            android:textSize="11sp"
            android:textColor="#0D3B66"
            android:background="#8FD0F0"
            android:minHeight="0dp"
            android:paddingTop="6dp"
            android:paddingBottom="6dp"
            android:text="" />
        <Button
            android:id="@+id/widget_routine2"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="4dp"
            android:textSize="11sp"
            android:textColor="#0D3B66"
            android:background="#8FD0F0"
            android:minHeight="0dp"
            android:paddingTop="6dp"
            android:paddingBottom="6dp"
            android:visibility="gone"
            android:text="" />
    </LinearLayout>
    <TextView
        android:id="@+id/widget_updated\""""

if s.count(anchor) != 1:
    print(f"ERROR layout: ancla x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, buttons)
open(p,'w',encoding='utf-8').write(s)
print("OK  layout: fila de botones de rutina")
PYEOF

# ---------------------------------------------------------------------------
# 5) Provider Kotlin: pintar favoritas + click con URI de rutina
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt'
s = open(p, encoding='utf-8').read()

if "import android.net.Uri" not in s:
    s = s.replace("import android.os.Bundle",
                  "import android.net.Uri\nimport android.os.Bundle", 1)

anchor = """        val refreshIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent)"""
block = """        val refreshIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent)

        // Botones de rutinas favoritas (deep link lmb10://routine?id=<id>)
        val fav1Name = prefs.getString("fav1_name", null)
        val fav1Id = prefs.getString("fav1_id", null)
        val fav2Name = prefs.getString("fav2_name", null)
        val fav2Id = prefs.getString("fav2_id", null)
        if (!tiny && !fav1Name.isNullOrEmpty() && !fav1Id.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_routines_row, View.VISIBLE)
            views.setTextViewText(R.id.widget_routine1, fav1Name)
            val i1 = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("lmb10://routine?id=$fav1Id"))
            views.setOnClickPendingIntent(R.id.widget_routine1, i1)
            if (!fav2Name.isNullOrEmpty() && !fav2Id.isNullOrEmpty()) {
                views.setViewVisibility(R.id.widget_routine2, View.VISIBLE)
                views.setTextViewText(R.id.widget_routine2, fav2Name)
                val i2 = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("lmb10://routine?id=$fav2Id"))
                views.setOnClickPendingIntent(R.id.widget_routine2, i2)
            } else {
                views.setViewVisibility(R.id.widget_routine2, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_routines_row, View.GONE)
        }"""

if s.count(anchor) != 1:
    print(f"ERROR kotlin: ancla x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, block)
open(p,'w',encoding='utf-8').write(s)
print("OK  provider Kotlin: botones de rutina con URI")
PYEOF

cat << 'DONE'
============================================================
FAVORITAS + BOTONES EN EL WIDGET aplicados. Compila:
  flutter build apk --release
============================================================
DONE
