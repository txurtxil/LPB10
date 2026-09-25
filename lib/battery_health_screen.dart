// Pantalla "Salud de la bateria" (N3/N3b): estimacion de capacidad util a
// partir de la energia medida en las cargas (ver battery_health.dart) y
// descarga pasiva en paradas. Todo se calcula con el historico local
// (trips.jsonl): no toca red ni la nube de Leapmotor.
//
// Criterios calibrados con LeapMotor Mate (N3b, v180): corriente minima
// de carga 2 A, corte por frio a 15 C de temperatura de paquete, y la
// cifra principal de descarga pasiva = perdida total / tiempo total
// aparcado (incluidas las paradas que no perdieron nada).

import 'package:flutter/material.dart';

import 'battery_health.dart';
import 'battery_report_pdf.dart' show informeSaludPdf, compartirPdf;
import 'consumption_temp.dart';
import 'history_archive.dart';
import 'widget_chart.dart' show gBatteryKwh;

class BatteryHealthScreen extends StatefulWidget {
  const BatteryHealthScreen({super.key});
  @override
  State<BatteryHealthScreen> createState() => _BatteryHealthScreenState();
}

class _BatteryHealthScreenState extends State<BatteryHealthScreen> {
  bool _cargando = true;
  ResumenSalud _salud = const ResumenSalud();
  List<ParadaPerdida> _paradas = [];
  ResumenDescarga _descarga = const ResumenDescarga();
  List<PuntoConsumo> _puntosConsumo = [];
  bool _verPctDia = true; // true: %/dia, false: % perdido por parada
  bool _exportandoPdf = false;

  /// Genera y comparte el informe PDF de salud (mas alla de Mate).
  Future<void> _exportarPdf() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_salud.capacidadKwh == null && _paradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'Aun no hay datos suficientes para un informe'
              : 'Not enough data for a report yet')));
      return;
    }
    setState(() => _exportandoPdf = true);
    try {
      final f = await informeSaludPdf(_salud, _descarga, _puntosConsumo);
      await compartirPdf(f);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es ? 'No se pudo generar el PDF' : 'Could not generate the PDF')));
      }
    } finally {
      if (mounted) setState(() => _exportandoPdf = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final m = await HistoryArchive.cargarMuestrasBat();
    final estim = estimarCapacidades(m);
    final paradas = calcularDescargaPasiva(m);
    if (!mounted) return;
    setState(() {
      _salud = resumirSalud(estim);
      _paradas = paradas;
      _descarga = resumirDescargaPasiva(paradas);
      _puntosConsumo = consumoVsTemp(m);
      _cargando = false;
    });
  }

  String _fecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final cap = _salud.capacidadKwh;
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Salud de la bateria' : 'Battery health'),
        actions: [
          IconButton(
            tooltip: es ? 'Exportar informe PDF' : 'Export PDF report',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportandoPdf ? null : _exportarPdf,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.monitor_heart_outlined,
                            size: 40, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 8),
                        if (cap == null)
                          Text(
                            es
                                ? 'Todavia no hay datos suficientes.\n\nCada punto es la energia medida durante una carga (integral de tension x corriente) dividida por la carga que añadio: una estimacion de la capacidad total del paquete. Solo se usan cargas con una subida apreciable y telemetria guardada; un punto suelto es ruidoso, asi que la cifra principal es la media de las cargas recientes. Los datos de tension/corriente empiezan a guardarse desde la v3.60.178: tras unas cuantas cargas completas aparecera aqui tu curva de capacidad.\n\nEs una estimacion, no una medicion de laboratorio.'
                                : 'Not enough data yet.\n\nEach point is the measured energy during a charge (voltage x current integral) divided by the charge it added: an estimate of the pack capacity. Only charges with a noticeable SoC rise and stored telemetry are used; a single point is noisy, so the main figure is the average of recent charges. Voltage/current data starts being stored from v3.60.178; after a few full charges your capacity curve will appear here.\n\nIt is an estimate, not a lab measurement.',
                            textAlign: TextAlign.center,
                          )
                        else ...[
                          Text(
                            '${cap.toStringAsFixed(1)} kWh',
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                          ),
                          Text(es
                              ? 'capacidad util estimada (media de las cargas recientes)'
                              : 'estimated usable capacity (recent charges average)'),
                          const SizedBox(height: 6),
                          Text(
                            es
                                ? 'Referencia de nuevo: ${gBatteryKwh.toStringAsFixed(1)} kWh -> salud ${(cap / gBatteryKwh * 100).toStringAsFixed(1)} %'
                                : 'As-new reference: ${gBatteryKwh.toStringAsFixed(1)} kWh -> health ${(cap / gBatteryKwh * 100).toStringAsFixed(1)} %',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            es
                                ? 'dispersion ±${_salud.dispersionPct?.toStringAsFixed(1) ?? '--'} % · ${_salud.numEstimaciones} cargas medidas${_salud.excluidasFrio > 0 ? ' · ${_salud.excluidasFrio} con bateria fria fuera del computo' : ''}'
                                : 'scatter ±${_salud.dispersionPct?.toStringAsFixed(1) ?? '--'} % · ${_salud.numEstimaciones} measured charges${_salud.excluidasFrio > 0 ? ' · ${_salud.excluidasFrio} cold-pack charges left out' : ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_salud.estimaciones.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(es ? 'Cargas medidas (mas recientes)' : 'Measured charges (most recent)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final e in _salud.estimaciones.reversed.take(15))
                    Card(
                      child: Opacity(
                        opacity: e.excluida ? 0.55 : 1.0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 86,
                                child: Text(_fecha(e.finMs),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LinearProgressIndicator(
                                      value: (e.capacidadKwh / 120.0).clamp(0.0, 1.0).toDouble(),
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.socIni.toStringAsFixed(0)}>${e.socFin.toStringAsFixed(0)} % · ${e.energiaKwh.toStringAsFixed(1)} kWh${e.tempMin != null ? ' · ${e.tempMin!.toStringAsFixed(0)} C' : ''}${e.excluida ? (es ? ' · fria: fuera de la salud' : ' · cold: left out') : ''}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 74,
                                child: Text('${e.capacidadKwh.toStringAsFixed(1)} kWh',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(es ? 'Descarga pasiva' : 'Vampire drain',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _descarga.pctDia == null
                              ? '--'
                              : '${_descarga.pctDia!.toStringAsFixed(2)} %/dia',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        Text(es
                            ? 'descarga habitual en reposo (${_descarga.numParadas} paradas, ${_descarga.horasTotales.toStringAsFixed(0)} h)'
                            : 'usual parked drain (${_descarga.numParadas} stops, ${_descarga.horasTotales.toStringAsFixed(0)} h)'),
                        const SizedBox(height: 4),
                        Text(
                          es
                              ? 'Carga perdida desde que se apaga el coche hasta el siguiente encendido: incluye la climatizacion con el coche apagado. La cifra es la perdida total entre el tiempo total aparcado en todas las paradas, incluidas las que no perdieron nada. Se calcula solo a partir de la telemetria registrada; no hay que introducir nada.'
                              : 'Charge lost from parking to next drive: includes climate while parked. The figure is total loss over total parked time across all stops, including those that lost nothing. Computed from stored telemetry; nothing to enter.',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_paradas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(value: true, label: Text(es ? '%/dia' : '%/day')),
                            ButtonSegment(value: false, label: Text(es ? '% perdido' : '% lost')),
                          ],
                          selected: {_verPctDia},
                          onSelectionChanged: (s) => setState(() => _verPctDia = s.first),
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _GraficoParadas(
                    paradas: _paradas.length > 12
                        ? _paradas.sublist(_paradas.length - 12)
                        : _paradas,
                    verPctDia: _verPctDia,
                    fecha: _fecha,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    es
                        ? 'Cada barra es un intervalo en el que el coche estuvo aparcado y sin cargar al menos una hora. Las barras palidas son paradas con caidas al nivel del ruido del sensor y no entran en la cifra principal.'
                        : 'Each bar is an interval with the car parked and not charging for at least one hour. Pale bars are stops with sensor-noise-level drops and do not count for the main figure.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 16),
                Text(es ? 'Consumo segun temperatura' : 'Consumption vs temperature',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _puntosConsumo.length < 3
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              es
                                  ? 'Cada punto es un tramo de conduccion: consumo (% de bateria por 100 km) frente a la temperatura. La temperatura exterior llega de Open-Meteo desde la v3.60.182; cuando haya tramos suficientes veras aqui la curva de tu coche (en frio consume mas).'
                                  : 'Each point is a driving leg: consumption (% of battery per 100 km) against temperature. Outdoor temperature comes from Open-Meteo since v3.60.182; once there are enough legs you will see your car curve here (cold costs more).',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          )
                        : SizedBox(
                            height: 180,
                            child: CustomPaint(
                              painter: _ScatterConsumoPainter(
                                  _puntosConsumo, Theme.of(context).colorScheme.primary),
                              child: const SizedBox.expand(),
                            ),
                          ),
                  ),
                ),
                if (_puntosConsumo.length >= 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      es
                          ? '${_puntosConsumo.length} tramos. Eje X: temperatura (C, exterior si la hay; del paquete si no). Eje Y: % de bateria por 100 km.'
                          : '${_puntosConsumo.length} legs. X axis: temperature (C, outdoor if available, pack otherwise). Y axis: % of battery per 100 km.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Nube de puntos consumo-temperatura con ejes y marcas en los extremos.
class _ScatterConsumoPainter extends CustomPainter {
  final List<PuntoConsumo> puntos;
  final Color color;
  _ScatterConsumoPainter(this.puntos, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const margenIzq = 34.0, margenAbajo = 20.0, margenArr = 8.0, margenDer = 8.0;
    final w = size.width - margenIzq - margenDer;
    final h = size.height - margenArr - margenAbajo;
    if (w <= 0 || h <= 0) return;

    var minT = puntos.first.temp, maxT = puntos.first.temp;
    var minC = puntos.first.pct100km, maxC = puntos.first.pct100km;
    for (final p in puntos) {
      if (p.temp < minT) minT = p.temp;
      if (p.temp > maxT) maxT = p.temp;
      if (p.pct100km < minC) minC = p.pct100km;
      if (p.pct100km > maxC) maxC = p.pct100km;
    }
    if (maxT - minT < 1) { minT -= 0.5; maxT += 0.5; }
    if (maxC - minC < 1) { minC -= 0.5; maxC += 0.5; }

    final ejes = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    final origen = Offset(margenIzq, margenArr + h);
    // ejes
    canvas.drawLine(origen, Offset(margenIzq, margenArr), ejes);
    canvas.drawLine(origen, Offset(margenIzq + w, margenArr + h), ejes);

    void etiqueta(String txt, Offset pos) {
      final tp = TextPainter(
          text: TextSpan(
              text: txt, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, pos);
    }

    etiqueta('${minT.toStringAsFixed(0)} C', Offset(margenIzq, margenArr + h + 4));
    final maxTLbl = '${maxT.toStringAsFixed(0)} C';
    final tpMax = TextPainter(
        text: TextSpan(
            text: maxTLbl, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
        textDirection: TextDirection.ltr)
      ..layout();
    tpMax.paint(canvas, Offset(margenIzq + w - tpMax.width, margenArr + h + 4));
    etiqueta(maxC.toStringAsFixed(0), Offset(2, margenArr));
    etiqueta(minC.toStringAsFixed(0), Offset(2, margenArr + h - 10));

    final puntosPaint = Paint()..color = color.withOpacity(0.65);
    for (final p in puntos) {
      final x = margenIzq + (p.temp - minT) / (maxT - minT) * w;
      final y = margenArr + h - (p.pct100km - minC) / (maxC - minC) * h;
      canvas.drawCircle(Offset(x, y), 3, puntosPaint);
    }
  }

  @override
  bool shouldRepaint(_ScatterConsumoPainter old) => old.puntos != puntos;
}

/// Barras por parada: %/dia o % perdido, palidas si la caida es ruido.
class _GraficoParadas extends StatelessWidget {
  final List<ParadaPerdida> paradas;
  final bool verPctDia;
  final String Function(int ms) fecha;
  const _GraficoParadas(
      {required this.paradas, required this.verPctDia, required this.fecha});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final valores = [for (final p in paradas) verPctDia ? p.pctDia : p.perdidaPct];
    final maxV = valores.fold<double>(0, (a, b) => b > a ? b : a);
    const alto = 110.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < paradas.length; i++)
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      valores[i].toStringAsFixed(verPctDia ? 2 : 1),
                      style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: maxV > 0 ? (alto * valores[i] / maxV).clamp(2.0, alto) : 2.0,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: paradas[i].esRuido ? color.withOpacity(0.3) : color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fecha(paradas[i].iniMs).substring(0, 5),
                      style: TextStyle(fontSize: 9, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
