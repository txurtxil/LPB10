// day_history_screen.dart
//
// Explorador del coste de energia por DIA (peticion de Luck): la tarjeta solo
// agrega hoy/ayer/7d/mes y una vez pasados esos periodos el detalle diario se
// perdia. Aqui cada dia del archivo permanente con sus km, kWh y euros,
// filtrable por mes.
import 'package:flutter/material.dart';

import 'daily_stats.dart';
import 'energy_cost.dart' show preciosPorDia, totalizar;

class DayHistoryScreen extends StatefulWidget {
  const DayHistoryScreen({super.key});
  @override
  State<DayHistoryScreen> createState() => _DayHistoryScreenState();
}

class _DayHistoryScreenState extends State<DayHistoryScreen> {
  bool _cargando = true;
  List<DayAgg> _dias = [];
  Map<String, double> _precios = {};
  String? _mesSel;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final days = await DailyStats.sync();
    final precios = await preciosPorDia();
    if (!mounted) return;
    setState(() {
      _dias = days.reversed.toList();
      _precios = precios;
      _cargando = false;
    });
  }

  static String _fmtDia(String d) {
    final p = d.split('-');
    if (p.length != 3) return d;
    return '${p[2]}/${p[1]}';
  }

  static String _mesDe(String d) => d.length >= 7 ? d.substring(0, 7) : d;

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final meses = <String>[];
    for (final a in _dias) {
      final m = _mesDe(a.d);
      if (!meses.contains(m)) meses.add(m);
    }
    final vis =
        _mesSel == null ? _dias : _dias.where((a) => _mesDe(a.d) == _mesSel).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Coste por dia' : 'Cost by day'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (meses.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(es ? 'Todas' : 'All'),
                            selected: _mesSel == null,
                            onSelected: (_) => setState(() => _mesSel = null),
                          ),
                        ),
                        for (final m in meses)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(m),
                              selected: _mesSel == m,
                              onSelected: (_) => setState(() => _mesSel = m),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: vis.isEmpty
                      ? Center(
                          child: Text(
                              es ? 'Sin datos en este periodo' : 'No data in this period'))
                      : ListView.separated(
                          itemCount: vis.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final a = vis[i];
                            final t = totalizar([a], _precios);
                            return ListTile(
                              dense: true,
                              title: Text(_fmtDia(a.d)),
                              subtitle: Text(
                                  '${t.km.toStringAsFixed(0)} km · ${t.kwh.toStringAsFixed(1)} kWh'),
                              trailing: Text(
                                t.hayEur ? '${t.eur.toStringAsFixed(2)} €' : '--',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
