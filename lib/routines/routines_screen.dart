// routines_screen.dart — Menu "Rutinas" de LMB10.
// Lanza rutinas al momento o programa su disparo por hora/dias.
// Estrella = favorita del widget (max 2). Texto de ayuda legible en oscuro.

import 'package:flutter/material.dart';

import '../leapmotor_engine.dart';
import 'routine_engine.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    super.key,
    required this.client,
    required this.vin,
    required this.pin,
    this.status,
    this.autoRunId,
  });

  final LeapmotorApiClient client;
  final String vin;
  final String pin;
  final VehicleStatus? status;
  final String? autoRunId;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Routine> _routines = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _routines = await RoutineStore.load();
    setState(() => _loading = false);
    if (widget.autoRunId != null) {
      final match = _routines.where((r) => r.id == widget.autoRunId);
      if (match.isNotEmpty) {
        await _run(match.first);
      }
    }
  }

  RoutineEngine get _engine =>
      RoutineEngine(client: widget.client, vin: widget.vin, pin: widget.pin);

  Future<void> _run(Routine r) async {
    setState(() => _busy = true);
    RoutineRunResult res;
    try {
      res = await _engine.run(r, status: widget.status);
    } catch (e) {
      res = RoutineRunResult(false, 0, 0, 1, '$e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${r.name}: ${res.summary}'),
        backgroundColor: res.ok ? null : Colors.red.shade700));
  }

  Future<void> _toggleFavorite(Routine r) async {
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

  Future<void> _toggleEnabled(Routine r, bool v) async {
    setState(() => r.enabled = v);
    await RoutineStore.saveAll(_routines);
  }

  Future<void> _editSchedule(Routine r) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: r.scheduleHour ?? 7, minute: r.scheduleMinute ?? 0),
      helpText: es ? 'Hora de disparo' : 'Trigger time',
    );
    if (picked == null) return;
    setState(() {
      r.scheduleHour = picked.hour;
      r.scheduleMinute = picked.minute;
      r.enabled = true;
    });
    await RoutineStore.saveAll(_routines);
  }

  Future<void> _clearSchedule(Routine r) async {
    setState(() {
      r.scheduleHour = null;
      r.scheduleMinute = null;
    });
    await RoutineStore.saveAll(_routines);
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Rutinas' : 'Routines')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.eco, color: Colors.green.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            es
                                ? 'Rutinas de autonomia: aprovechan la energia de la red (coche enchufado) para no gastar bateria. Las programadas se ejecutan en segundo plano; recuerda el PIN en el login para que funcionen con la app cerrada.'
                                : 'Range routines use grid power (car plugged in) to spare the battery. Scheduled ones run in the background; remember the PIN at login so they work with the app closed.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blueGrey.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._routines.map((r) => _routineCard(r, es)),
              ],
            ),
    );
  }

  Widget _routineCard(Routine r, bool es) {
    final schedule = r.isScheduled
        ? '${r.scheduleHour!.toString().padLeft(2, '0')}:${r.scheduleMinute!.toString().padLeft(2, '0')}'
            '${r.scheduleDays.isEmpty ? (es ? ' cada dia' : ' every day') : ' ${_daysLabel(r.scheduleDays, es)}'}'
        : (es ? 'Solo manual' : 'Manual only');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(r.favorite ? Icons.star : Icons.star_border,
                      color: r.favorite ? Colors.amber : null),
                  tooltip: es ? 'Favorita del widget' : 'Widget favorite',
                  onPressed: () => _toggleFavorite(r),
                ),
                Expanded(
                  child: Text(r.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (r.isScheduled)
                  Switch(
                    value: r.enabled,
                    onChanged: (v) => _toggleEnabled(r, v),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ...r.steps.map((s) {
              final cond =
                  routineConditionLabel(s.condition, s.intParam, es: es);
              return Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  '\u2022 ${routineActionLabel(s, es: es)}${cond.isEmpty ? '' : '  ($cond)'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 16, color: Theme.of(context).hintColor),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(schedule,
                        style: Theme.of(context).textTheme.bodySmall)),
                TextButton(
                  onPressed: () => _editSchedule(r),
                  child: Text(es ? 'Programar' : 'Schedule'),
                ),
                if (r.isScheduled)
                  TextButton(
                    onPressed: () => _clearSchedule(r),
                    child: Text(es ? 'Quitar' : 'Clear'),
                  ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _run(r),
                icon: const Icon(Icons.play_arrow),
                label: Text(es ? 'Ejecutar ahora' : 'Run now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _daysLabel(List<int> days, bool es) {
    const esD = ['', 'L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const enD = ['', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final names = es ? esD : enD;
    return days.map((d) => names[d]).join('');
  }
}
