// comparison_screen.dart
//
// Comparativa del B10 con un vehiculo de referencia (Tesla Model 3 por
// defecto, configurable). El consumo y coste del B10 salen de la
// telemetria real acumulada (DailyStats + precios reales pagados), no de
// ficha tecnica. El del vehiculo de referencia sale de datos publicos, y se
// guarda como RANGO porque la ficha WLTP y el uso real no coinciden.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'daily_stats.dart';
import 'energy_cost.dart';
import 'comparison_profile.dart';
import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

const _cBlue = Color(0xFF0D3B66);
const _cGood = Color(0xFF2A9D8F);
const _cOver = Color(0xFFE76F51);
const _cLine = Color(0xFFE63946);
const _cCardBg = Color(0xFFCFE8F7);
const _cCardSoft = Color(0xFFE7F4FB);

/// Normaliza dos valores reales (B10 y referencia) a [0,1] para un eje del
/// radar. masEsMejor=false invierte la escala (precio, consumo, coste).
List<double> _normalizarEje(double a, double b, {required bool masEsMejor}) {
  final lo = math.min(a, b) * 0.85;
  final hi = math.max(a, b) * 1.15;
  if ((hi - lo).abs() < 1e-9) return [0.5, 0.5];
  double norm(double v) {
    final n = masEsMejor ? (v - lo) / (hi - lo) : (hi - v) / (hi - lo);
    return n.clamp(0.0, 1.0);
  }
  return [norm(a), norm(b)];
}

Path _dashPath(Path source, [double dash = 5, double gap = 4]) {
  final dest = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var dibujar = true;
    while (distance < metric.length) {
      final largo = dibujar ? dash : gap;
      if (dibujar) {
        dest.addPath(
          metric.extractPath(distance, math.min(distance + largo, metric.length)),
          Offset.zero,
        );
      }
      distance += largo;
      dibujar = !dibujar;
    }
  }
  return dest;
}

class RadarChartPainter extends CustomPainter {
  final List<String> ejes;
  final List<double> b10;
  final List<double> ref;
  RadarChartPainter({required this.ejes, required this.b10, required this.ref});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2 - 28;
    final n = ejes.length;

    Offset punto(int i, double v) {
      final angulo = -math.pi / 2 + i * (2 * math.pi / n);
      return Offset(cx + r * v * math.cos(angulo), cy + r * v * math.sin(angulo));
    }

    void anillo(double v, {bool discontinuo = false}) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = punto(i, v);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = discontinuo ? 1.4 : 1
        ..color = discontinuo ? _cLine : _cBlue.withOpacity(0.2);
      if (discontinuo) {
        canvas.drawPath(_dashPath(path, 4, 4), paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }

    for (final v in [0.25, 0.5, 0.75]) {
      anillo(v);
    }
    anillo(1.0, discontinuo: true);

    final ejePaint = Paint()
      ..color = _cBlue.withOpacity(0.2)
      ..strokeWidth = 1;
    for (var i = 0; i < n; i++) {
      canvas.drawLine(Offset(cx, cy), punto(i, 1.0), ejePaint);
      final etiqueta = TextPainter(
        text: TextSpan(
          text: ejes[i],
          style: const TextStyle(color: _cBlue, fontSize: 11, fontFamily: 'monospace'),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final p = punto(i, 1.16);
      etiqueta.paint(canvas, Offset(p.dx - etiqueta.width / 2, p.dy - etiqueta.height / 2));
    }

    void poligono(List<double> valores, Color color) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = punto(i, valores[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..style = PaintingStyle.fill..color = color.withOpacity(0.25));
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = color);
    }

    poligono(ref, _cOver);
    poligono(b10, _cGood);
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) =>
      oldDelegate.b10 != b10 || oldDelegate.ref != ref;
}

class PaybackChartPainter extends CustomPainter {
  final double precioB10;
  final double precioRef;
  final double costeB10PorKm;
  final double costeRefBajoPorKm;
  final double costeRefAltoPorKm;
  final double kmMax;

  PaybackChartPainter({
    required this.precioB10,
    required this.precioRef,
    required this.costeB10PorKm,
    required this.costeRefBajoPorKm,
    required this.costeRefAltoPorKm,
    required this.kmMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 56.0, padR = 12.0, padT = 12.0, padB = 26.0;
    final yMax = (precioRef + kmMax * costeRefAltoPorKm) * 1.05;

    double x(double km) => padL + (km / kmMax) * (size.width - padL - padR);
    double y(double v) => size.height - padB - (v / yMax) * (size.height - padT - padB);

    Path linea(double Function(double) f) {
      final path = Path();
      const pasos = 40;
      for (var i = 0; i <= pasos; i++) {
        final km = kmMax * i / pasos;
        final p = Offset(x(km), y(f(km)));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path;
    }

    double yB10(double km) => precioB10 + km * costeB10PorKm;
    double yRefBajo(double km) => precioRef + km * costeRefBajoPorKm;
    double yRefAlto(double km) => precioRef + km * costeRefAltoPorKm;

    final banda = Path.from(linea(yRefBajo));
    const pasos = 40;
    for (var i = pasos; i >= 0; i--) {
      final km = kmMax * i / pasos;
      banda.lineTo(x(km), y(yRefAlto(km)));
    }
    banda.close();
    canvas.drawPath(banda, Paint()..color = _cOver.withOpacity(0.18));

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _cOver;
    canvas.drawPath(_dashPath(linea(yRefBajo)), dash);
    canvas.drawPath(_dashPath(linea(yRefAlto)), dash);

    canvas.drawPath(
      linea(yB10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = _cGood,
    );

    final ejes = Paint()
      ..color = _cBlue.withOpacity(0.35)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(padL, padT), Offset(padL, size.height - padB), ejes);
    canvas.drawLine(Offset(padL, size.height - padB), Offset(size.width - padR, size.height - padB), ejes);

    for (final frac in [0.0, 0.5, 1.0]) {
      final km = kmMax * frac;
      _texto(canvas, '${(km / 1000).round()}k km', Offset(x(km), size.height - padB + 6), anclaCentro: true);
    }
    for (final frac in [0.0, 0.5, 1.0]) {
      final v = yMax * frac;
      _texto(canvas, '${(v / 1000).toStringAsFixed(0)}k \u20AC', Offset(padL - 8, y(v)), anclaDerecha: true);
    }
  }

  void _texto(Canvas canvas, String s, Offset pos, {bool anclaCentro = false, bool anclaDerecha = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(color: _cBlue, fontSize: 10, fontFamily: 'monospace')),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = pos.dx;
    if (anclaCentro) dx -= tp.width / 2;
    if (anclaDerecha) dx -= tp.width;
    tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant PaybackChartPainter oldDelegate) => true;
}

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});
  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  bool _loading = true;
  bool _hayDatos = false;
  double _b10Kwh100 = 0;
  double _b10CostePer100 = 0;
  double _eurKwhMedio = 0;
  double _b10Precio = kB10PrecioListaDefecto;
  bool _b10PrecioConfirmado = false;
  ReferenceVehicle _ref = kTeslaModel3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await DailyStats.load();
    final precios = await preciosPorDia();
    final t = totalizar(days, precios);
    final ref = await loadReferenceVehicle();
    final precioPagado = await loadB10PrecioPagado();
    if (!mounted) return;
    setState(() {
      _hayDatos = t.km > 0;
      _b10Kwh100 = t.km > 0 ? t.kwh / t.km * 100 : 0;
      _b10CostePer100 = (t.hayEur && t.km > 0) ? t.eur / t.km * 100 : 0;
      _eurKwhMedio = (t.hayEur && t.kwh > 0) ? t.eur / t.kwh : 0;
      _ref = ref;
      _b10PrecioConfirmado = precioPagado != null;
      _b10Precio = precioPagado ?? kB10PrecioListaDefecto;
      _loading = false;
    });
  }

  Future<void> _editar() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final precioCtrl = TextEditingController(text: _b10Precio.toStringAsFixed(0));
    final refNombreCtrl = TextEditingController(text: _ref.nombre);
    final refPrecioCtrl = TextEditingController(text: _ref.precio.toStringAsFixed(0));
    final refBajoCtrl = TextEditingController(text: _ref.kwh100Bajo.toStringAsFixed(1));
    final refAltoCtrl = TextEditingController(text: _ref.kwh100Alto.toStringAsFixed(1));
    final refBateriaCtrl = TextEditingController(text: _ref.bateriaKwh.toStringAsFixed(1));
    final refAutonomiaCtrl = TextEditingController(text: _ref.autonomiaKm.toStringAsFixed(0));

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                es ? 'Datos de la comparativa' : 'Comparison data',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                es
                    ? 'Lo que pagaste de verdad por tu B10, y los datos del coche con el que te comparas.'
                    : 'What you really paid for your B10, and the data of the car you are comparing against.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: es ? 'Precio pagado por el B10 (EUR)' : 'Price paid for the B10 (EUR)',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                es ? 'Vehiculo de referencia' : 'Reference vehicle',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: refNombreCtrl,
                decoration: InputDecoration(labelText: es ? 'Nombre' : 'Name'),
              ),
              TextField(
                controller: refPrecioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: es ? 'Precio (EUR)' : 'Price (EUR)'),
              ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: refBajoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: es ? 'kWh/100 bajo' : 'kWh/100 low'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: refAltoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: es ? 'kWh/100 alto' : 'kWh/100 high'),
                  ),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: refBateriaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: es ? 'Bateria (kWh)' : 'Battery (kWh)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: refAutonomiaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: es ? 'Autonomia (km)' : 'Range (km)'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(es ? 'Guardar' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
      if (precio != null && precio > 0) {
        await saveB10PrecioPagado(precio);
      }
      final nuevoRef = ReferenceVehicle(
        nombre: refNombreCtrl.text.trim().isEmpty ? _ref.nombre : refNombreCtrl.text.trim(),
        precio: double.tryParse(refPrecioCtrl.text.replaceAll(',', '.')) ?? _ref.precio,
        kwh100Bajo: double.tryParse(refBajoCtrl.text.replaceAll(',', '.')) ?? _ref.kwh100Bajo,
        kwh100Alto: double.tryParse(refAltoCtrl.text.replaceAll(',', '.')) ?? _ref.kwh100Alto,
        bateriaKwh: double.tryParse(refBateriaCtrl.text.replaceAll(',', '.')) ?? _ref.bateriaKwh,
        autonomiaKm: double.tryParse(refAutonomiaCtrl.text.replaceAll(',', '.')) ?? _ref.autonomiaKm,
      );
      await saveReferenceVehicle(nuevoRef);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFD),
      appBar: AppBar(
        backgroundColor: _cBlue,
        title: Text(es ? 'Comparativa' : 'Comparison'),
        actions: [IconButton(icon: const Icon(Icons.tune), onPressed: _editar)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hayDatos
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      es
                          ? 'Todavia no hay suficiente historial de conduccion para calcular tu consumo real. Vuelve cuando hayas recorrido algunos km.'
                          : 'Not enough driving history yet to calculate your real consumption. Come back after a few km.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildContent(es),
    );
  }

  Widget _buildContent(bool es) {
    final diffPrecio = _ref.precio - _b10Precio;
    final hayPrecio = _eurKwhMedio > 0 && _b10CostePer100 > 0;

    final ejes = [
      es ? 'Eficiencia' : 'Efficiency',
      es ? 'Autonomia' : 'Range',
      es ? 'Bateria' : 'Battery',
      'Precio',
      es ? 'Coste/100km' : 'Cost/100km',
    ];
    final ejeEficiencia = _normalizarEje(_b10Kwh100, _ref.kwh100Medio, masEsMejor: false);
    final ejeAutonomia = _normalizarEje(gMaxRangeKm, _ref.autonomiaKm, masEsMejor: true);
    final ejeBateria = _normalizarEje(gBatteryKwh, _ref.bateriaKwh, masEsMejor: true);
    final ejePrecio = _normalizarEje(_b10Precio, _ref.precio, masEsMejor: false);
    final refCostePer100 = _ref.kwh100Medio * _eurKwhMedio;
    final ejeCoste = hayPrecio
        ? _normalizarEje(_b10CostePer100, refCostePer100, masEsMejor: false)
        : [0.5, 0.5];

    final b10Vals = [ejeEficiencia[0], ejeAutonomia[0], ejeBateria[0], ejePrecio[0], ejeCoste[0]];
    final refVals = [ejeEficiencia[1], ejeAutonomia[1], ejeBateria[1], ejePrecio[1], ejeCoste[1]];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!_b10PrecioConfirmado)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _cOver.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Text(
              es
                  ? 'Usando precio de lista (${kB10PrecioListaDefecto.toStringAsFixed(0)} \u20AC). Toca el icono de arriba para poner lo que pagaste de verdad.'
                  : 'Using list price (${kB10PrecioListaDefecto.toStringAsFixed(0)} \u20AC). Tap the icon above to set what you really paid.',
              style: const TextStyle(color: _cBlue, fontSize: 12.5),
            ),
          ),
        Center(
          child: Column(
            children: [
              Text(
                '${diffPrecio >= 0 ? '+' : ''}${diffPrecio.toStringAsFixed(0)} \u20AC',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: diffPrecio >= 0 ? _cOver : _cGood,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                child: Text(
                  es
                      ? 'diferencia de precio de compra, ${_ref.nombre} frente a tu B10'
                      : 'purchase price difference, ${_ref.nombre} vs your B10',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _tarjetaVehiculo(
                es: es,
                titulo: 'Leapmotor B10',
                subtitulo: es ? 'Datos reales de telemetria' : 'Real telemetry data',
                consumo: '${_b10Kwh100.toStringAsFixed(1)} kWh/100km',
                precio: '${_b10Precio.toStringAsFixed(0)} \u20AC',
                bateria: '${gBatteryKwh.toStringAsFixed(1)} kWh',
                autonomia: '${gMaxRangeKm.round()} km',
                coste: hayPrecio ? '${_b10CostePer100.toStringAsFixed(2)} \u20AC/100km' : '--',
                color: _cGood,
                fondo: _cCardBg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _tarjetaVehiculo(
                es: es,
                titulo: _ref.nombre,
                subtitulo: es ? 'Ficha publica, configurable' : 'Public spec, configurable',
                consumo: '${_ref.kwh100Bajo.toStringAsFixed(1)}\u2013${_ref.kwh100Alto.toStringAsFixed(1)} kWh/100km',
                precio: '${_ref.precio.toStringAsFixed(0)} \u20AC',
                bateria: '${_ref.bateriaKwh.toStringAsFixed(1)} kWh',
                autonomia: '${_ref.autonomiaKm.round()} km',
                coste: hayPrecio
                    ? '${(_ref.kwh100Bajo * _eurKwhMedio).toStringAsFixed(2)}\u2013${(_ref.kwh100Alto * _eurKwhMedio).toStringAsFixed(2)} \u20AC/100km'
                    : '--',
                color: _cOver,
                fondo: _cCardSoft,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          es ? 'COORDENADAS \u00b7 QUIEN GANA EN CADA EJE' : 'COORDINATES \u00b7 WHO WINS EACH AXIS',
          style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cCardSoft, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _leyenda(_cGood, 'Leapmotor B10'),
                const SizedBox(width: 20),
                _leyenda(_cOver, _ref.nombre),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: RadarChartPainter(ejes: ejes, b10: b10Vals, ref: refVals),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (hayPrecio) ...[
          Text(
            es ? 'COSTE ACUMULADO POR KM' : 'CUMULATIVE COST BY KM',
            style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _cCardSoft, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, 240),
                    painter: PaybackChartPainter(
                      precioB10: _b10Precio,
                      precioRef: _ref.precio,
                      costeB10PorKm: _b10CostePer100 / 100,
                      costeRefBajoPorKm: _ref.kwh100Bajo * _eurKwhMedio / 100,
                      costeRefAltoPorKm: _ref.kwh100Alto * _eurKwhMedio / 100,
                      kmMax: 200000,
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  es
                      ? 'Linea solida: tu B10 (coste real). Banda discontinua: rango del ${_ref.nombre} entre su consumo declarado y el de uso normal.'
                      : 'Solid line: your B10 (real cost). Dashed band: ${_ref.nombre} range between declared and normal-use consumption.',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(
          es ? 'DATOS, COLUMNA A COLUMNA' : 'DATA, SIDE BY SIDE',
          style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _cCardSoft, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            _filaTabla(es ? 'Consumo' : 'Consumption', '${_b10Kwh100.toStringAsFixed(1)} kWh/100km',
                '${_ref.kwh100Bajo.toStringAsFixed(1)}-${_ref.kwh100Alto.toStringAsFixed(1)} kWh/100km'),
            _filaTabla(es ? 'Bateria' : 'Battery', '${gBatteryKwh.toStringAsFixed(1)} kWh', '${_ref.bateriaKwh.toStringAsFixed(1)} kWh'),
            _filaTabla(es ? 'Autonomia' : 'Range', '${gMaxRangeKm.round()} km', '${_ref.autonomiaKm.round()} km'),
            _filaTabla('Precio', '${_b10Precio.toStringAsFixed(0)} \u20AC', '${_ref.precio.toStringAsFixed(0)} \u20AC'),
          ]),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _cBlue, borderRadius: BorderRadius.circular(20)),
          child: Text(
            _veredicto(es, diffPrecio, hayPrecio),
            style: const TextStyle(color: Color(0xFFEAF4FC), fontSize: 13, height: 1.6),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _veredicto(bool es, double diffPrecio, bool hayPrecio) {
    if (!hayPrecio) {
      return es
          ? 'Configura tu precio de electricidad (icono de Ajustes -> Coste de la energia) para ver el veredicto completo con coste real.'
          : 'Set your electricity price (Settings -> Energy cost icon) to see the full verdict with real cost.';
    }
    final refCoste = _ref.kwh100Medio * _eurKwhMedio;
    final ganaEficienciaRef = refCoste < _b10CostePer100;
    if (!ganaEficienciaRef) {
      return es
          ? 'Con tu consumo real, ${_ref.nombre} no gana en coste electrico ni de lejos: ni siquiera en su mejor escenario compensa la diferencia de precio de compra. La ventaja del B10 en tu caso es clara.'
          : 'With your real consumption, ${_ref.nombre} does not win on running cost: not even in its best case does it offset the purchase price gap. The B10 wins clearly in your case.';
    }
    return es
        ? 'En el mejor de los casos, ${_ref.nombre} podria ahorrar algo de electricidad frente a tu B10, pero al ritmo actual harian falta cientos de miles de km para recuperar la diferencia de precio de compra.'
        : 'In the best case, ${_ref.nombre} could save a bit on electricity versus your B10, but at this rate it would take hundreds of thousands of km to recover the purchase price gap.';
  }

  Widget _leyenda(Color c, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(texto, style: const TextStyle(fontSize: 12)),
    ]);
  }

  Widget _filaTabla(String etiqueta, String b10, String ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text(etiqueta, style: const TextStyle(fontSize: 12.5))),
        Expanded(flex: 3, child: Text(b10, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _cGood))),
        Expanded(flex: 3, child: Text(ref, textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5, color: _cOver))),
      ]),
    );
  }

  Widget _tarjetaVehiculo({
    required bool es,
    required String titulo,
    required String subtitulo,
    required String consumo,
    required String precio,
    required String bateria,
    required String autonomia,
    required String coste,
    required Color color,
    required Color fondo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitulo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _cBlue)),
          const SizedBox(height: 10),
          Text(consumo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          _lineaCard(es ? 'Bateria' : 'Battery', bateria),
          _lineaCard(es ? 'Autonomia' : 'Range', autonomia),
          _lineaCard(es ? 'Coste/100km' : 'Cost/100km', coste),
          _lineaCard('Precio', precio),
        ],
      ),
    );
  }

  Widget _lineaCard(String etiqueta, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
        Text(valor, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _cBlue)),
      ]),
    );
  }
}
