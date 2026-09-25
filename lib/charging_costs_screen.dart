// Pantalla "Costes de carga" (clon de LeapMotor Mate): sesiones de carga
// detectadas en el historico local, clasificadas AC/DC/HPC por potencia
// pico, con tarifas editables en EUR/kWh y totales por mes.
//
// La energia es la que entra al paquete (integral V x A); la de red es algo
// mayor por las perdidas del cargador. Las tarifas se guardan en
// tarifas.json dentro del directorio del historico.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'battery_report_pdf.dart' show listadoCostesPdf, compartirPdf;
import 'charge_cost.dart';
import 'charging_costs.dart';
import 'battery_health.dart' show MuestraBat;
import 'history_archive.dart';

class ChargingCostsScreen extends StatefulWidget {
  const ChargingCostsScreen({super.key});
  @override
  State<ChargingCostsScreen> createState() => _ChargingCostsScreenState();
}

class _ChargingCostsScreenState extends State<ChargingCostsScreen> {
  bool _cargando = true;
  bool _exportandoPdf = false;

  /// Genera y comparte el listado PDF de costes de carga.
  Future<void> _exportarPdf() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_sesiones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'Aun no hay sesiones de carga registradas'
              : 'No charging sessions recorded yet')));
      return;
    }
    setState(() => _exportandoPdf = true);
    try {
      final f = await listadoCostesPdf(_sesiones, _meses, _tarifasActuales());
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

  List<SesionCarga> _sesiones = [];
  List<MuestraBat> _muestras = const [];
  Map<String, MesCarga> _meses = {};
  final _ac = TextEditingController();
  final _dc = TextEditingController();
  final _hpc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ac.dispose();
    _dc.dispose();
    _hpc.dispose();
    super.dispose();
  }

  Tarifas _tarifasActuales() => Tarifas(
      ac: double.tryParse(_ac.text.replaceAll(',', '.')),
      dc: double.tryParse(_dc.text.replaceAll(',', '.')),
      hpc: double.tryParse(_hpc.text.replaceAll(',', '.')));

  Future<void> _cargar() async {
    // Tarifas guardadas
    try {
      final d = await HistoryArchive.dir();
      final f = File('${d.path}/tarifas.json');
      if (await f.exists()) {
        final m = Map<String, dynamic>.from(json.decode(await f.readAsString()) as Map);
        _ac.text = (m['ac'] as num?)?.toString() ?? '';
        _dc.text = (m['dc'] as num?)?.toString() ?? '';
        _hpc.text = (m['hpc'] as num?)?.toString() ?? '';
      }
    } catch (_) {}
    final muestras = await HistoryArchive.cargarMuestrasBat();
    _muestras = muestras;
    final sesiones = detectarSesiones(muestras);
    if (!mounted) return;
    setState(() {
      _sesiones = sesiones;
      _meses = agregarPorMes(sesiones, _tarifasActuales());
      _cargando = false;
    });
  }

  Future<void> _guardarTarifas() async {
    try {
      final d = await HistoryArchive.dir();
      final f = File('${d.path}/tarifas.json');
      await f.writeAsString(json.encode({
        'ac': double.tryParse(_ac.text.replaceAll(',', '.')),
        'dc': double.tryParse(_dc.text.replaceAll(',', '.')),
        'hpc': double.tryParse(_hpc.text.replaceAll(',', '.')),
      }));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _meses = agregarPorMes(_sesiones, _tarifasActuales()));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(Localizations.localeOf(context).languageCode == 'es'
          ? 'Tarifas guardadas'
          : 'Tariffs saved'),
      duration: const Duration(seconds: 2),
    ));
  }

  String _fecha(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _etiquetaTipo(TipoCarga t) => t == TipoCarga.ac
      ? 'AC'
      : (t == TipoCarga.dc ? 'DC' : 'HPC');

  /// Hoja de detalle de una sesion: curva de potencia medida y formulario
  /// de coste real (lo pagado y los kWh que marco el cargador), que da la
  /// eficiencia real de la carga.
  Future<void> _detalleSesion(SesionCarga s) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final curva = curvaPotencia(_muestras, s.iniMs, s.finMs);
    final costes = await ChargeCostStore.loadAll();
    final guardado = costes[s.iniMs];
    if (!mounted) return;
    final eurCtrl = TextEditingController(
        text: guardado?.eur?.toString() ?? '');
    final kwhCtrl = TextEditingController(
        text: guardado?.kwhCargador?.toString() ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final estimado = costeSesion(s, _tarifasActuales());
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final kwhCargador =
                double.tryParse(kwhCtrl.text.replaceAll(',', '.'));
            final eurReal = double.tryParse(eurCtrl.text.replaceAll(',', '.'));
            final efic = eficienciaReal(s.energiaKwh, kwhCargador);
            final durMin = (s.finMs - s.iniMs) / 60000.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_etiquetaTipo(s.tipo)} · ${_fecha(s.iniMs)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.socIni.toStringAsFixed(0)}>${s.socFin.toStringAsFixed(0)} % · '
                      '${s.energiaKwh.toStringAsFixed(1)} kWh al paquete · '
                      'pico ${s.potMaxKw.toStringAsFixed(0)} kW · '
                      '${durMin.toStringAsFixed(0)} min',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 10),
                    if (curva.length >= 2) ...[
                      Text(es ? 'Curva de potencia' : 'Power curve',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 140,
                        child: CustomPaint(
                          painter: _CurvaCargaPainter(
                              curva, Theme.of(ctx).colorScheme.primary),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(es ? 'Coste real de esta carga' : 'Real cost of this charge',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      es
                          ? 'Estimado por tarifa: ${estimado == null ? '--' : '${estimado.toStringAsFixed(2)} EUR'}. Si anotas lo pagado de verdad (y los kWh que marco el cargador), el listado usa el dato real y calcula la eficiencia de la carga.'
                          : 'Tariff estimate: ${estimado == null ? '--' : '${estimado.toStringAsFixed(2)} EUR'}. If you note what you actually paid (and the kWh the charger reported), the listing uses the real figure and computes charging efficiency.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: eurCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: es ? 'Pagado (EUR)' : 'Paid (EUR)',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setSheet(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: kwhCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText:
                                  es ? 'kWh del cargador' : 'Charger kWh',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setSheet(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (efic != null)
                      Text(
                        es
                            ? 'Eficiencia real: ${efic.toStringAsFixed(1)} % (${s.energiaKwh.toStringAsFixed(1)} kWh al paquete de ${kwhCargador!.toStringAsFixed(1)} kWh del cargador)'
                            : 'Real efficiency: ${efic.toStringAsFixed(1)} % (${s.energiaKwh.toStringAsFixed(1)} kWh into the pack out of ${kwhCargador!.toStringAsFixed(1)} kWh from the charger)',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    if (eurReal != null)
                      Text(
                        es
                            ? 'Coste real: ${eurReal.toStringAsFixed(2)} EUR'
                            : 'Real cost: ${eurReal.toStringAsFixed(2)} EUR',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: () async {
                          await ChargeCostStore.put(ChargeCost(
                            ts: s.iniMs,
                            eur: eurReal,
                            kwhCargador: kwhCargador,
                            tipo: s.tipo == TipoCarga.ac ? 'casa' : 'publica',
                          ));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(es ? 'Guardar' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    eurCtrl.dispose();
    kwhCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final ahora = DateTime.now();
    final claveMes = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';
    final mes = _meses[claveMes];
    final tarifas = _tarifasActuales();
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Costes de carga' : 'Charging costs'),
        actions: [
          IconButton(
            tooltip: es ? 'Exportar listado PDF' : 'Export PDF listing',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(es ? 'Tarifas (EUR/kWh)' : 'Tariffs (EUR/kWh)',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final e in [
                              ('AC', _ac),
                              ('DC', _dc),
                              ('HPC', _hpc),
                            ])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: TextField(
                                    controller: e.$2,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: e.$1,
                                      isDense: true,
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(
                                        () => _meses = agregarPorMes(_sesiones, _tarifasActuales())),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: _guardarTarifas,
                            child: Text(es ? 'Guardar' : 'Save'),
                          ),
                        ),
                        Text(
                          es
                              ? 'La energia mostrada es la que entra al paquete (medida por el coche); la de red es algo mayor por las perdidas del cargador. AC <= 11 kW, DC hasta 100 kW, HPC por encima.'
                              : 'Energy shown is what enters the pack (measured by the car); grid energy is slightly higher due to charger losses. AC <= 11 kW, DC up to 100 kW, HPC above.',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          mes == null || mes.coste == null
                              ? '--'
                              : '${mes.coste!.toStringAsFixed(2)} EUR',
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                        ),
                        Text(es ? 'coste de carga este mes' : 'charging cost this month'),
                        const SizedBox(height: 6),
                        Text(
                          mes == null
                              ? (es ? 'Sin sesiones de carga registradas este mes.' : 'No charging sessions recorded this month.')
                              : '${mes.sesiones} ${es ? 'sesiones' : 'sessions'} · AC ${mes.kwhAc.toStringAsFixed(1)} kWh · DC ${mes.kwhDc.toStringAsFixed(1)} kWh · HPC ${mes.kwhHpc.toStringAsFixed(1)} kWh',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_sesiones.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(es ? 'Sesiones de carga (mas recientes)' : 'Charging sessions (most recent)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  for (final s in _sesiones.reversed.take(30))
                    Card(
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(_etiquetaTipo(s.tipo),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                            '${s.energiaKwh.toStringAsFixed(1)} kWh · ${s.potMaxKw.toStringAsFixed(0)} kW pico'),
                        subtitle: Text(
                            '${_fecha(s.iniMs)} · ${s.socIni.toStringAsFixed(0)}>${s.socFin.toStringAsFixed(0)} %'),
                        trailing: Text(
                          costeSesion(s, tarifas) == null
                              ? '--'
                              : '${costeSesion(s, tarifas)!.toStringAsFixed(2)} EUR',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // Detalle: curva de potencia + coste real anotado.
                        onTap: () => _detalleSesion(s),
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    es
                        ? 'Todavia no hay sesiones de carga registradas con telemetria (la tension/corriente se guarda desde la v3.60.178). Tras unas cuantas cargas apareceran aqui.'
                        : 'No charging sessions with telemetry yet (voltage/current is stored since v3.60.178). After a few charges they will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Curva de potencia (kW) de una sesion de carga.
class _CurvaCargaPainter extends CustomPainter {
  final List<(int, double)> puntos;
  final Color color;
  _CurvaCargaPainter(this.puntos, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const margenIzq = 30.0, margenAbajo = 18.0, margenArr = 8.0, margenDer = 8.0;
    final w = size.width - margenIzq - margenDer;
    final h = size.height - margenArr - margenAbajo;
    if (w <= 0 || h <= 0 || puntos.length < 2) return;

    final t0 = puntos.first.$1, t1 = puntos.last.$1;
    var maxKw = 0.0;
    for (final p in puntos) {
      if (p.$2 > maxKw) maxKw = p.$2;
    }
    if (maxKw <= 0) return;

    final ejes = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(Offset(margenIzq, margenArr + h),
        Offset(margenIzq + w, margenArr + h), ejes);
    canvas.drawLine(
        Offset(margenIzq, margenArr), Offset(margenIzq, margenArr + h), ejes);

    void etiqueta(String txt, Offset pos) {
      final tp = TextPainter(
          text: TextSpan(
              text: txt,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, pos);
    }

    etiqueta('${maxKw.toStringAsFixed(0)} kW', Offset(0, margenArr));
    final durMin = ((t1 - t0) / 60000).round();
    etiqueta('0', Offset(margenIzq, margenArr + h + 4));
    etiqueta('$durMin min',
        Offset(margenIzq + w - 30, margenArr + h + 4));

    final relleno = Path();
    final linea = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < puntos.length; i++) {
      final x = margenIzq + (puntos[i].$1 - t0) / (t1 - t0) * w;
      final y = margenArr + h - puntos[i].$2 / maxKw * h;
      if (i == 0) {
        path.moveTo(x, y);
        relleno.moveTo(x, margenArr + h);
        relleno.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        relleno.lineTo(x, y);
      }
    }
    relleno.lineTo(margenIzq + w, margenArr + h);
    relleno.close();
    canvas.drawPath(
        relleno, Paint()..color = color.withOpacity(0.15));
    canvas.drawPath(path, linea);
  }

  @override
  bool shouldRepaint(_CurvaCargaPainter old) => old.puntos != puntos;
}
