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

import 'daily_stats.dart';
import 'price_screen.dart';
import 'widget_chart.dart' show kB10BatteryKwh;

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
double kwhOf(DayAgg a) => a.soc / 100.0 * kB10BatteryKwh;

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

    var kHoy = 0.0, mHoy = 0.0, kMes = 0.0, mMes = 0.0, k7 = 0.0, m7 = 0.0;
    for (final a in days) {
      if (a.d == hoyKey) {
        kHoy += kwhOf(a);
        mHoy += a.km;
      }
      if (a.d.startsWith(mesKey)) {
        kMes += kwhOf(a);
        mMes += a.km;
      }
    }
    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
    for (final a in last7) {
      k7 += kwhOf(a);
      m7 += a.km;
    }

    if (!mounted) return;
    setState(() {
      _price = p;
      _kwhHoy = kHoy;
      _kmHoy = mHoy;
      _kwh7 = k7;
      _km7 = m7;
      _kwhMes = kMes;
      _kmMes = mMes;
      _loading = false;
    });
  }

  Widget _fila(String titulo, double kwh, double km) {
    final p = _price;
    final eur = p == null ? null : kwh * p.eurKwh;
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
            _fila(es ? 'Hoy' : 'Today', _kwhHoy, _kmHoy),
            _fila(es ? 'Ultimos 7 dias' : 'Last 7 days', _kwh7, _km7),
            _fila(es ? 'Este mes' : 'This month', _kwhMes, _kmMes),
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
/// importa widget_chart.dart para kB10BatteryKwh, y hacerlo al reves crearia
/// una dependencia circular.
///
/// Devuelve cadenas vacias si el usuario no ha puesto precio o si aun no hay
/// agregado. En ese caso no se pinta nada: mejor que filas con guiones
/// ocupando sitio en un widget donde el espacio es oro.
Future<({String widget, String car})> buildCostLines() async {
  const vacio = (widget: '', car: '');
  try {
    final p = await EnergyPrice.load();
    if (p == null) return vacio;
    final days = await DailyStats.load();
    if (days.isEmpty) return vacio;

    final ahora = DateTime.now();
    final hoyKey = DailyStats.dayKey(ahora);
    final mesKey = DailyStats.monthKey(ahora);

    var kHoy = 0.0, kMes = 0.0, k7 = 0.0;
    for (final a in days) {
      if (a.d == hoyKey) kHoy += kwhOf(a);
      if (a.d.startsWith(mesKey)) kMes += kwhOf(a);
    }
    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
    for (final a in last7) {
      k7 += kwhOf(a);
    }

    // Coma decimal: el resto del widget ya la usa (_d1 en widget_chart.dart).
    String eur(double kwh) =>
        (kwh * p.eurKwh).toStringAsFixed(2).replaceAll('.', ',');

    // Ancho: las lineas mas largas del grafico rondan los 25 caracteres
    // ("Consumo kWh/100  obj 15,6"). Estas se quedan en 19, asi que caben.
    final w = StringBuffer()
      ..writeln('Gasto hoy ' + eur(kHoy).padLeft(6) + ' \u20AC')
      ..writeln('Gasto 7d  ' + eur(k7).padLeft(6) + ' \u20AC')
      ..write('Gasto mes ' + eur(kMes).padLeft(6) + ' \u20AC');

    final c = 'Hoy ' +
        eur(kHoy) +
        ' \u20AC  \u00B7  7 dias ' +
        eur(k7) +
        ' \u20AC  \u00B7  Mes ' +
        eur(kMes) +
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
Future<({String d7, String mes, String ano})> buildCarTotals() async {
  const vacio = (d7: '', mes: '', ano: '');
  try {
    final days = await DailyStats.load();
    if (days.isEmpty) return vacio;
    final p = await EnergyPrice.load();
    final ahora = DateTime.now();
    final mesKey = DailyStats.monthKey(ahora);
    final anoKey = ahora.year.toString() + '-';

    String linea(Iterable<DayAgg> ds) {
      var km = 0.0, kwh = 0.0;
      for (final a in ds) {
        km += a.km;
        kwh += kwhOf(a);
      }
      if (km <= 0) return '';
      final eur = p == null ? '' : (kwh * p.eurKwh).toStringAsFixed(2);
      return km.toStringAsFixed(0) +
          '|' +
          kwh.toStringAsFixed(1) +
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
