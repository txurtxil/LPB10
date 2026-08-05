import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'maintenance.dart';

/// Mantenimiento periodico segun el manual del vehiculo.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  List<EstadoMant> _estado = [];
  int _odo = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    var odo = 0;
    try {
      odo = int.tryParse(
              (await HomeWidget.getWidgetData<String>('odometro')) ?? '') ??
          0;
    } catch (_) {}
    final st = await Mantenimiento.estado(odo);
    if (!mounted) return;
    setState(() {
      _odo = odo;
      _estado = st;
      _cargando = false;
    });
  }

  Future<void> _anotar(ItemMant it, RegistroMant? previo) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final kmCtrl = TextEditingController(
        text: (previo?.km ?? _odo) > 0 ? (previo?.km ?? _odo).toString() : '');
    var fecha = previo != null && previo.fechaMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(previo.fechaMs)
        : DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(es ? it.nombre : it.nombreEn),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(es ? it.nota : it.notaEn,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                Text(
                  es
                      ? 'Cuando se hizo por ultima vez:'
                      : 'When was it last done:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (it.km > 0)
                  TextField(
                    controller: kmCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: es ? 'Kilometros' : 'Odometer',
                      helperText: _odo > 0
                          ? (es ? 'Ahora: $_odo km' : 'Now: $_odo km')
                          : null,
                      suffixText: 'km',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                if (it.km > 0 && it.meses > 0) const SizedBox(height: 12),
                if (it.meses > 0)
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: fecha,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setSt(() => fecha = d);
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(fecha.day.toString().padLeft(2, '0') +
                        '/' +
                        fecha.month.toString().padLeft(2, '0') +
                        '/' +
                        fecha.year.toString()),
                  ),
              ],
            ),
          ),
          actions: [
            if (previo != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(es ? 'Cancelar' : 'Cancel'),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(es ? 'Guardar' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    await Mantenimiento.guardar(RegistroMant(
      it.id,
      int.tryParse(kmCtrl.text.trim()) ?? 0,
      it.meses > 0 ? fecha.millisecondsSinceEpoch : 0,
    ));
    await _cargar();
  }

  String _restante(EstadoMant e, bool es) {
    if (e.sinDatos) return es ? 'Sin anotar' : 'Not set';
    if (e.vencido) return es ? 'VENCIDO' : 'OVERDUE';
    final partes = <String>[];
    if (e.kmRestantes != null) {
      partes.add(e.kmRestantes.toString() + ' km');
    }
    if (e.diasRestantes != null) {
      final d = e.diasRestantes!;
      partes.add(d > 60
          ? (d ~/ 30).toString() + (es ? ' meses' : ' months')
          : d.toString() + (es ? ' dias' : ' days'));
    }
    if (partes.isEmpty) return '--';
    return (es ? 'Faltan ' : 'In ') + partes.join(es ? ' o ' : ' or ');
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Mantenimiento' : 'Maintenance')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    es
                        ? 'Intervalos del manual del vehiculo. El coche no informa de '
                            'sus revisiones, asi que hay que anotar cuando se hizo cada '
                            'una.\n\nSe avisa por lo que ocurra primero, kilometros o '
                            'tiempo, tal como indica el fabricante.'
                        : 'Intervals from the vehicle manual. The car does not report '
                            'its servicing, so each one must be noted.\n\nWhichever '
                            'comes first, distance or time, as the maker states.',
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                if (_odo > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    (es ? 'Odometro actual: ' : 'Current odometer: ') +
                        _odo.toString() +
                        ' km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
                const SizedBox(height: 8),
                for (final e in _estado)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(es ? e.item.nombre : e.item.nombreEn),
                      subtitle: Text(
                        _intervalo(e.item, es) + '\n' + _restante(e, es),
                        style: TextStyle(
                          fontSize: 12,
                          color: e.vencido
                              ? const Color(0xFFB3341F)
                              : (e.sinDatos ? Colors.grey : null),
                          fontWeight: e.vencido ? FontWeight.bold : null,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () async {
                        final reg = await Mantenimiento.cargar();
                        if (!context.mounted) return;
                        await _anotar(e.item, reg[e.item.id]);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  String _intervalo(ItemMant it, bool es) {
    final p = <String>[];
    if (it.km > 0) p.add(it.km.toString() + ' km');
    if (it.meses > 0) {
      p.add(it.meses >= 12
          ? (it.meses ~/ 12).toString() + (es ? ' anos' : ' years')
          : it.meses.toString() + (es ? ' meses' : ' months'));
    }
    return (es ? 'Cada ' : 'Every ') + p.join(es ? ' o ' : ' or ');
  }
}
