set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart "backups_widget/main.dart.bak_$TS"
cp "$K/QuickWidgetProvider.kt" "backups_widget/QuickWidgetProvider.kt.bak_$TS"
echo "Backups con sufijo .bak_$TS"

python3 - << 'PYEOF'
import sys
def rd(p): return open(p, encoding='utf-8').read()
def wr(p, s): open(p, 'w', encoding='utf-8').write(s)
def rep(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        print("ABORTA %s: %d ocurrencias" % (tag, n)); sys.exit(1)
    return s.replace(old, new)

p = 'lib/main.dart'
s = rd(p)
antes = (s.count('(')-s.count(')'), s.count('{')-s.count('}'))

s = rep(s, '''class _AddressCache {
  static double? _lastLat;
  static double? _lastLon;
  static String? _lastAddress;

  static Future<String> resolve(double lat, double lon) async {
    // Solo vuelve a consultar Nominatim si el coche se movio > ~300 metros,
    // para respetar su politica de uso (evitar peticiones repetidas cada 90s).
    if (_lastAddress != null && _lastLat != null && _lastLon != null) {
      final movedMeters = Geolocator.distanceBetween(_lastLat!, _lastLon!, lat, lon);
      if (movedMeters < 300) return _lastAddress!;
    }''',
'''class _AddressCache {
  static double? _lastLat;
  static double? _lastLon;
  static String? _lastAddress;

  static const _kLat = 'addr_lat_v1';
  static const _kLon = 'addr_lon_v1';
  static const _kTxt = 'addr_txt_v1';

  /// La cache era SOLO estatica en memoria, y el refresco de fondo corre en
  /// OTRO isolate con sus propias estaticas: para el siempre estaba vacia. Si
  /// se llama desde ahi sin persistir, cada refresco de WorkManager seria una
  /// peticion a Nominatim cada 15 minutos por cada usuario, que es exactamente
  /// el uso automatizado que su politica prohibe. Persistida, la regla de los
  /// 300 m funciona entre isolates y solo se llama al mover el coche.
  static Future<void> _cargarSiHaceFalta() async {
    if (_lastAddress != null) return;
    try {
      final t = await _storage.read(key: _kTxt);
      final la = double.tryParse(await _storage.read(key: _kLat) ?? '');
      final lo = double.tryParse(await _storage.read(key: _kLon) ?? '');
      if (t != null && t.isNotEmpty && la != null && lo != null) {
        _lastAddress = t;
        _lastLat = la;
        _lastLon = lo;
      }
    } catch (_) {}
  }

  static Future<void> _guardar(String txt, double lat, double lon) async {
    try {
      await _storage.write(key: _kTxt, value: txt);
      await _storage.write(key: _kLat, value: lat.toString());
      await _storage.write(key: _kLon, value: lon.toString());
    } catch (_) {}
  }

  static Future<String> resolve(double lat, double lon) async {
    await _cargarSiHaceFalta();
    // Solo vuelve a consultar Nominatim si el coche se movio > ~300 metros,
    // para respetar su politica de uso (evitar peticiones repetidas cada 90s).
    if (_lastAddress != null && _lastLat != null && _lastLon != null) {
      final movedMeters = Geolocator.distanceBetween(_lastLat!, _lastLon!, lat, lon);
      if (movedMeters < 300) return _lastAddress!;
    }''', 'cache-persistente')

s = rep(s, '''        _lastAddress = resolved;
        _lastLat = lat;
        _lastLon = lon;
        return resolved;''',
'''        _lastAddress = resolved;
        _lastLat = lat;
        _lastLon = lon;
        await _guardar(resolved, lat, lon);
        return resolved;''', 'guardar')

s = rep(s, "  await HomeWidget.saveWidgetData<String>('lon', s.longitude != null ? s.longitude.toString() : '');",
'''  await HomeWidget.saveWidgetData<String>('lon', s.longitude != null ? s.longitude.toString() : '');
  // Direccion legible para el widget. La cache persistida evita llamar a
  // Nominatim en cada refresco: solo sale peticion si el coche se ha movido
  // mas de 300 m desde la ultima resuelta.
  if (s.latitude != null && s.longitude != null) {
    try {
      final dir = await _AddressCache.resolve(s.latitude!, s.longitude!);
      await HomeWidget.saveWidgetData<String>('carAddress', dir);
    } catch (_) {}
  }''', 'guardar-widget')

wr(p, s)
d = (s.count('(')-s.count(')'), s.count('{')-s.count('}'))
print("  main.dart balance %s -> %s" % (str(antes), str(d)))
if antes != d:
    print("ABORTA: balance alterado"); sys.exit(1)

p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/QuickWidgetProvider.kt'
s = rd(p)
s = rep(s, '        v.setViewVisibility(R.id.qw_info3, View.GONE)',
'''        // Donde esta aparcado. Es la pregunta que mas veces hace mirar el
        // movil y no la responde ningun otro widget.
        val dir = p.getString("carAddress", null)
        if (!dir.isNullOrEmpty()) {
            v.setTextViewText(R.id.qw_info3, "\\uD83D\\uDCCD  " + dir)
            v.setViewVisibility(R.id.qw_info3, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info3, View.GONE)
        }''', 'direccion-kotlin')
wr(p, s)
k = (s.count('('), s.count(')'), s.count('{'), s.count('}'))
print("  kotlin %d/%d  %d/%d" % k)
if k[0] != k[1] or k[2] != k[3]:
    print("ABORTA: descuadre kotlin"); sys.exit(1)
print("OK")
PYEOF

echo "--- verificaciones ---"
echo -n "carAddress en dart: "; grep -c "'carAddress'" lib/main.dart
echo -n "carAddress en kotlin: "; grep -c 'carAddress' "$K/QuickWidgetProvider.kt"
echo -n "cache persistida: "; grep -c '_cargarSiHaceFalta' lib/main.dart
echo
flutter analyze 2>&1 | grep '• lib/' | grep error || echo "analyze: sin errores"
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
