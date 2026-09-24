// Pantalla "Salud de la bateria" (N3): estimacion de capacidad util a
// partir de la energia medida en las cargas (ver battery_health.dart) y
// descarga pasiva en paradas. Todo se calcula con el historico local
// (trips.jsonl): no toca red ni la nube de Leapmotor.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'battery_health.dart';
import 'history_archive.dart';
import 'widget_chart.dart' show gBatteryKwh;

Future<List<MuestraBat>> _cargarMuestras() async {
  final d = await HistoryArchive.dir();
  final f = File('${d.path}/trips.jsonl');
  if (!await f.exists()) return const [];
  final out = <MuestraBat>[];
  for (final line in await f.readAsLines()) {
    final t = line.trim();
    if (t.isEmpty) continue;
    try {
      final m = Map<String, dynamic>.from(json.decode(t) as Map);
      final ts = m['ts'];
      final km = m['km'];
      final soc = m['soc'];
      if (ts is! int || km is! num || soc is! num) continue;
      out.add(MuestraBat(ts, km.toInt(), soc.toDouble(),
          v: (m['v'] as num?)?.toDouble(),
          a: (m['a'] as num?)?.toDouble()));
    } catch (_) {}
  }
  return out;
}

class BatteryHealthScreen extends StatefulWidget {
  const BatteryHealthScreen({super.key});
  @override
  State<BatteryHealthScreen> createState() => _BatteryHealthScreenState();
}

class _BatteryHealthScreenState extends State<BatteryHealthScreen> {
  bool _cargando = true;
  ResumenSalud _salud = const ResumenSalud();
  List<ParadaPerdida> _paradas = [];
  double? _perdidaMediana;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final m = await _cargarMuestras();
    final estim = estimarCapacidades(m);
    final paradas = calcularDescargaPasiva(m);
    if (!mounted) return;
    setState(() {
      _salud = resumirSalud(estim);
      _paradas = paradas;
      _perdidaMediana = mediana(paradas.map((p) => p.pctDia).toList());
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
      appBar: AppBar(title: Text(es ? 'Salud de la bateria' : 'Battery health')),
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
                                ? 'Todavia no hay datos suficientes.\n\nCada punto es la energia medida durante una carga (integral de tension x corriente) dividida por la carga que añadio: una estimacion de la capacidad total del paquete. Los datos de tension/corriente empiezan a guardarse desde la v3.60.178: tras unas cuantas cargas completas aparecera aqui tu curva de capacidad.\n\nEs una estimacion, no una medicion de laboratorio.'
                                : 'Not enough data yet.\n\nEach point is the measured energy during a charge (voltage x current integral) divided by the charge it added: an estimate of the pack capacity. Voltage/current data starts being stored from v3.60.178; after a few full charges your capacity curve will appear here.\n\nIt is an estimate, not a lab measurement.',
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
                                ? 'Nominal del modelo: ${gBatteryKwh.toStringAsFixed(1)} kWh (${(cap / gBatteryKwh * 100).toStringAsFixed(0)} %) · dispersion ±${_salud.dispersionPct?.toStringAsFixed(1) ?? '--'} % · ${_salud.numEstimaciones} ${es ? 'cargas medidas' : 'measured charges'}'
                                : 'Model nominal: ${gBatteryKwh.toStringAsFixed(1)} kWh (${(cap / gBatteryKwh * 100).toStringAsFixed(0)} %) · scatter ±${_salud.dispersionPct?.toStringAsFixed(1) ?? '--'} % · ${_salud.numEstimaciones} measured charges',
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
                                    value: (e.capacidadKwh / 120.0).clamp(0.0, 1.0),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${e.socIni.toStringAsFixed(0)}>${e.socFin.toStringAsFixed(0)} % · ${e.energiaKwh.toStringAsFixed(1)} kWh',
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
                          _perdidaMediana == null
                              ? (es ? '--' : '--')
                              : '${_perdidaMediana!.toStringAsFixed(1)} %/dia',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        Text(es
                            ? 'perdida habitual en reposo (mediana de ${_paradas.length} paradas)'
                            : 'usual parked drain (median of ${_paradas.length} stops)'),
                        const SizedBox(height: 4),
                        Text(
                          es
                              ? 'Carga perdida desde que se apaga el coche hasta el siguiente encendido: climatizacion en standby, TCU, etc. Se calcula solo a partir de la telemetria registrada; no hay que introducir nada.'
                              : 'Charge lost from parking to next drive: standby climate, TCU, etc. Computed from stored telemetry; nothing to enter.',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ),
                for (final p in _paradas.reversed.take(10))
                  ListTile(
                    dense: true,
                    title: Text(_fecha(p.iniMs),
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                        '${(p.finMs - p.iniMs) ~/ 3600000} h · -${p.perdidaPct.toStringAsFixed(1)} %',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text('${p.pctDia.toStringAsFixed(2)} %/dia',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
    );
  }
}
