// Coste de la energia consumida.
//
// Que mide: los kWh que el coche ha GASTADO conduciendo, sacados del agregado
// diario (daily_stats.dart), multiplicados por el precio que el usuario haya
// configurado.
//
// Que NO mide, y es importante: no son los kWh que marca el contador de casa.
// Nosotros partimos del SoC, o sea de la energia que entra en la bateria; entre
// el enchufe y la bateria se pierde un 10-15% en el proceso de carga. Se decidio
// (27/07/2026) no aplicar factor de correccion, asi que la cifra sale por debajo
// de lo que factura la comercializadora. La interfaz lo advierte.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'charge_cost.dart';
import 'daily_stats.dart';
import 'price_screen.dart';
import 'widget_chart.dart' show gBatteryKwh;

const _priceStorage = FlutterSecureStorage();
const kEnergyPriceKey = 'lm_energy_price_v1';

/// Se guarda como estructura y no como numero suelto, para poder anadir tramos
/// horarios (valle/llano/punta) mas adelante sin migrar lo ya guardado:
///   {"mode":"single","eur_kwh":0.1234}
///   {"mode":"bands", ...}            <- futuro
class EnergyPrice {
  final String mode;
  final double eurKwh;

  const EnergyPrice({this.mode = 'single', required this.eurKwh});

  static Future<EnergyPrice?> load() async {
    try {
      final raw = await _priceStorage.read(key: kEnergyPriceKey);
      if (raw == null || raw.isEmpty) return null;
      final m = Map<String, dynamic>.from(json.decode(raw) as Map);
      final v = m['eur_kwh'];
      if (v is! num || v <= 0) return null;
      return EnergyPrice(
          mode: (m['mode'] as String?) ?? 'single', eurKwh: v.toDouble());
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(double eurKwh) async {
    await _priceStorage.write(
        key: kEnergyPriceKey,
        value: json.encode({'mode': 'single', 'eur_kwh': eurKwh}));
  }

  static Future<void> clear() async {
    await _priceStorage.delete(key: kEnergyPriceKey);
  }
}

/// kWh que representa un agregado. DayAgg.soc es la caida de bateria acumulada
/// de los tramos que pasaron el filtro de plausibilidad.
double kwhOf(DayAgg a) => a.soc / 100.0 * gBatteryKwh;

/// Euros por kWh aplicables a cada dia, segun la ULTIMA carga anterior.
///
/// Asi el coste deja de asumir que siempre se carga en casa: si el martes
/// cargaste en un rapido a 0,59, los kilometros del miercoles se cobran a ese
/// precio. Y si la siguiente carga no se toca, vuelve sola al precio de casa.
///
/// El precio se expresa por kWh que ENTRARON EN LA BATERIA. Cuando el usuario
/// anota el total pagado, ese precio ya lleva dentro las perdidas de carga,
/// porque pago la energia que entrego el cargador y no la que llego a la
/// bateria. Es mas exacto que la estimacion con el precio de casa.
Future<Map<String, double>> preciosPorDia() async {
  final out = <String, double>{};
  try {
    final casa = (await EnergyPrice.load())?.eurKwh;
    final days = await DailyStats.load();
    if (days.isEmpty) return out;
    final cargas = await ChargeRebuild.fromTrips();
    final costes = await ChargeCostStore.loadAll();

    final tramos = <List<double>>[]; // [endTs, precio]
    for (final c in cargas) {
      final kwh = c.kwh;
      if (kwh <= 0) continue;
      final m = costes[c.startTs];
      double? p;
      if (m != null && m.eur != null) {
        p = m.eur! / kwh;
      } else if (m != null && m.eurKwh != null) {
        p = m.eurKwh! * (m.kwhCargador ?? kwh) / kwh;
      } else {
        p = casa;
      }
      if (p != null) tramos.add([c.endTs.toDouble(), p]);
    }
    tramos.sort((a, b) => a[0].compareTo(b[0]));

    for (final d in days) {
      DateTime dia;
      try {
        dia = DateTime.parse(d.d);
      } catch (_) {
        continue;
      }
      final finDia =
          dia.add(const Duration(days: 1)).millisecondsSinceEpoch.toDouble();
      double? p;
      for (final t in tramos) {
        if (t[0] <= finDia) {
          p = t[1];
        } else {
          break;
        }
      }
      p ??= casa;
      if (p != null) out[d.d] = p;
    }
  } catch (_) {}
  return out;
}

/// Suma km, kWh y euros de un conjunto de dias aplicando el precio de cada uno.
({double km, double kwh, double eur, bool hayEur}) totalizar(
    Iterable<DayAgg> ds, Map<String, double> precios) {
  var km = 0.0, kwh = 0.0, eur = 0.0;
  var hay = false;
  for (final a in ds) {
    final k = kwhOf(a);
    km += a.kmAll;
    kwh += k;
    final p = precios[a.d];
    if (p != null) {
      eur += k * p;
      hay = true;
    }
  }
  return (km: km, kwh: kwh, eur: eur, hayEur: hay);
}

class EnergyCostCard extends StatefulWidget {
  const EnergyCostCard({super.key});

  @override
  State<EnergyCostCard> createState() => _EnergyCostCardState();
}

class _EnergyCostCardState extends State<EnergyCostCard> {
  static const _bg = Color(0xFFD6E9FF);
  static const _fg = Color(0xFF0D3B66);

  EnergyPrice? _price;
  bool _loading = true;
  double _kwhHoy = 0, _kwh7 = 0, _kwhMes = 0;
  double _kmHoy = 0, _km7 = 0, _kmMes = 0;
  double _eurHoy = 0, _eur7 = 0, _eurMes = 0;
  bool _hayEur = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EnergyCostCard old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    final p = await EnergyPrice.load();
    final days = await DailyStats.load();
    final ahora = DateTime.now();
    final hoyKey = DailyStats.dayKey(ahora);
    final mesKey = DailyStats.monthKey(ahora);

    final precios = await preciosPorDia();
    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
    final tHoy = totalizar(days.where((a) => a.d == hoyKey), precios);
    final tMes = totalizar(days.where((a) => a.d.startsWith(mesKey)), precios);
    final t7 = totalizar(last7, precios);

    if (!mounted) return;
    setState(() {
      _price = p;
      _kwhHoy = tHoy.kwh;
      _kmHoy = tHoy.km;
      _eurHoy = tHoy.eur;
      _kwh7 = t7.kwh;
      _km7 = t7.km;
      _eur7 = t7.eur;
      _kwhMes = tMes.kwh;
      _kmMes = tMes.km;
      _eurMes = tMes.eur;
      _hayEur = tHoy.hayEur || t7.hayEur || tMes.hayEur;
      _loading = false;
    });
  }

  Widget _fila(String titulo, double kwh, double km, double eurCalc) {
    final eur = _hayEur ? eurCalc : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(titulo,
                style: const TextStyle(color: _fg, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text('${km.toStringAsFixed(0)} km',
                textAlign: TextAlign.end,
                style: const TextStyle(color: _fg, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text('${kwh.toStringAsFixed(1)} kWh',
                textAlign: TextAlign.end,
                style: const TextStyle(color: _fg, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(
                eur == null ? '--' : '${eur.toStringAsFixed(2)} \u20AC',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: _fg, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirPrecio() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const PriceScreen()));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_loading) return const SizedBox.shrink();

    return Card(
      color: _bg,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(es ? 'Coste de la energia' : 'Energy cost',
                      style: const TextStyle(
                          color: _fg,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                InkWell(
                  onTap: _abrirPrecio,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.tune, color: _fg, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_price == null)
              InkWell(
                onTap: _abrirPrecio,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    es
                        ? 'Toca el icono de arriba para indicar cuanto pagas por kWh. Sin ese dato solo se muestran los kilovatios.'
                        : 'Tap the icon above to set your price per kWh. Without it only kilowatt-hours are shown.',
                    style: const TextStyle(color: _fg, fontSize: 12),
                  ),
                ),
              ),
            _fila(es ? 'Hoy' : 'Today', _kwhHoy, _kmHoy, _eurHoy),
            _fila(es ? 'Ultimos 7 dias' : 'Last 7 days', _kwh7, _km7, _eur7),
            _fila(es ? 'Este mes' : 'This month', _kwhMes, _kmMes, _eurMes),
            const SizedBox(height: 8),
            Text(
              es
                  ? 'Energia gastada al conducir, medida en la bateria. Tu factura sera algo mayor: cargar tiene perdidas que aqui no se cuentan.'
                  : 'Energy used while driving, measured at the battery. Your bill will be somewhat higher: charging losses are not included here.',
              style: const TextStyle(
                  color: _fg, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lineas de gasto para el widget de inicio y para Android Auto.
///
/// Se calcula aqui y NO en widget_chart.dart a proposito: energy_cost.dart ya
/// importa widget_chart.dart para gBatteryKwh, y hacerlo al reves crearia
/// una dependencia circular.
///
/// Devuelve cadenas vacias si el usuario no ha puesto precio o si aun no hay
/// agregado. En ese caso no se pinta nada: mejor que filas con guiones
/// ocupando sitio en un widget donde el espacio es oro.
Future<({String widget, String car})> buildCostLines() async {
  const vacio = (widget: '', car: '');
  try {
    final days = await DailyStats.load();
    if (days.isEmpty) return vacio;
    final precios = await preciosPorDia();
    if (precios.isEmpty) return vacio;

    final ahora = DateTime.now();
    final hoyKey = DailyStats.dayKey(ahora);
    final mesKey = DailyStats.monthKey(ahora);
    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;

    final tHoy = totalizar(days.where((a) => a.d == hoyKey), precios);
    final tMes = totalizar(days.where((a) => a.d.startsWith(mesKey)), precios);
    final t7 = totalizar(last7, precios);
    // Coma decimal: el resto del widget ya la usa (_d1 en widget_chart.dart).
    String eur(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    String km(double v) => v.toStringAsFixed(0);

    // Mismo ancho de 19 caracteres que la tabla diaria, para que las columnas
    // de km y euros queden en la misma vertical en todo el widget:
    //   etiqueta(7) km(5) euro(7).
    final w = StringBuffer()
      ..writeln('Totales' + 'km'.padLeft(5) + '\u20AC'.padLeft(7))
      ..writeln('Hoy'.padRight(7) +
          km(tHoy.km).padLeft(5) +
          eur(tHoy.eur).padLeft(7))
      ..writeln('7 dias'.padRight(7) +
          km(t7.km).padLeft(5) +
          eur(t7.eur).padLeft(7))
      ..write('Mes'.padRight(7) +
          km(tMes.km).padLeft(5) +
          eur(tMes.eur).padLeft(7));

    final c = 'Hoy ' +
        eur(tHoy.eur) +
        ' \u20AC  \u00B7  7 dias ' +
        eur(t7.eur) +
        ' \u20AC  \u00B7  Mes ' +
        eur(tMes.eur) +
        ' \u20AC';

    return (widget: w.toString(), car: c);
  } catch (_) {
    return vacio;
  }
}

/// Totales para la pantalla de Consumo del coche.
///
/// Cada cadena viene como "km|kWh|euros". Los euros van vacios si el usuario
/// no ha configurado precio, y entonces el coche solo pinta km y kWh.
///
/// El ano arranca donde arranque el historico: si la app se instalo en julio,
/// el total anual son los meses que haya, no doce.
/// Series para el grafico del coche: dias, semanas y meses.
///
/// Cada elemento es "etiqueta:kwh100:euros:km". Se agrupa desde el archivo
/// permanente con las mismas claves que usa DailyStats, y los euros se
/// calculan sumando los dias de cada grupo: aplicar totalizar() sobre un
/// agregado ya reducido no encontraria su precio, porque los precios van por
/// dia y la clave de una semana no es la de ningun dia.
Future<({String dias, String semanas, String meses})> buildCarSeries() async {
  const vacio = (dias: '', semanas: '', meses: '');
  try {
    final days = await DailyStats.load();
    if (days.isEmpty) return vacio;
    final precios = await preciosPorDia();

    String serie(String Function(DateTime) clave, int max) {
      final grupos = <String, List<DayAgg>>{};
      for (final a in days) {
        final dt = DateTime.tryParse(a.d);
        if (dt == null) continue;
        (grupos[clave(dt)] ??= []).add(a);
      }
      final claves = grupos.keys.toList()..sort();
      final recorte = claves.length > max ? claves.sublist(claves.length - max) : claves;
      final out = <String>[];
      for (final k in recorte) {
        final g = grupos[k]!;
        final t = totalizar(g, precios);
        if (t.km <= 0) continue;
        final socTot = g.fold<double>(0, (s, a) => s + a.soc);
        final kmTot = g.fold<double>(0, (s, a) => s + a.km);
        if (kmTot <= 0) continue;
        final kwh100 = socTot / kmTot * gBatteryKwh;
        out.add(k.split('-').last +
            ':' + kwh100.toStringAsFixed(1) +
            ':' + (t.hayEur ? t.eur.toStringAsFixed(2) : '') +
            ':' + t.km.toStringAsFixed(0));
      }
      return out.join(',');
    }

    return (
      dias: serie((t) => t.toIso8601String().substring(0, 10), 14),
      semanas: serie(DailyStats.weekKey, 8),
      meses: serie(DailyStats.monthKey, 12),
    );
  } catch (_) {
    return vacio;
  }
}

Future<({String d7, String mes, String ano})> buildCarTotals() async {
  const vacio = (d7: '', mes: '', ano: '');
  try {
    final days = await DailyStats.load();
    if (days.isEmpty) return vacio;
    final precios = await preciosPorDia();
    final ahora = DateTime.now();
    final mesKey = DailyStats.monthKey(ahora);
    final anoKey = ahora.year.toString() + '-';

    String linea(Iterable<DayAgg> ds) {
      final t = totalizar(ds, precios);
      if (t.km <= 0) return '';
      final eur = t.hayEur ? t.eur.toStringAsFixed(2) : '';
      return t.km.toStringAsFixed(0) +
          '|' +
          t.kwh.toStringAsFixed(1) +
          '|' +
          eur;
    }

    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
    return (
      d7: linea(last7),
      mes: linea(days.where((a) => a.d.startsWith(mesKey))),
      ano: linea(days.where((a) => a.d.startsWith(anoKey))),
    );
  } catch (_) {
    return vacio;
  }
}
