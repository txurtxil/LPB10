import 'package:flutter/material.dart';
import 'leapmotor_engine.dart';
import 'l10n/generated/app_localizations.dart';

class PreconditioningScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  final String pin;
  const PreconditioningScreen({super.key, required this.client, required this.vehicle, required this.pin});

  @override
  State<PreconditioningScreen> createState() => _PreconditioningScreenState();
}

class _PreconditioningScreenState extends State<PreconditioningScreen> {
  bool _busy = false;
  String? _message;
  List<Map<String, dynamic>> _schedule = [];

  bool _heat = true;
  double _temperature = 22;
  bool _steeringWheelHeat = false;
  TimeOfDay _time = TimeOfDay.now();
  final Set<int> _selectedDays = {};

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _busy = true);
    try {
      final schedule = await widget.client.getPrepareCarSchedule(widget.vehicle.vin);
      setState(() { _schedule = schedule; _busy = false; });
    } catch (e) {
      setState(() { _message = 'Error leyendo horario: $e'; _busy = false; });
    }
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() { _busy = true; _message = null; });
    try {
      await action();
      setState(() => _message = '$label: OK');
      await _loadSchedule();
    } catch (e) {
      setState(() => _message = '$label: Error - $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _prepareNow() async {
    await _run('Precondicionar ahora', () => widget.client.prepareCarNow(
          widget.vehicle.vin, widget.pin,
          heat: _heat, temperature: _temperature.round().toString(), steeringWheelHeat: _steeringWheelHeat,
        ));
  }

  Future<void> _addScheduleEntry() async {
    final now = DateTime.now();
    var startDateTime = DateTime(now.year, now.month, now.day, _time.hour, _time.minute);
    if (startDateTime.isBefore(now) && _selectedDays.isEmpty) {
      startDateTime = startDateTime.add(const Duration(days: 1));
    }
    final entry = widget.client.buildPrepareCarEntry(
      startTime: startDateTime,
      days: _selectedDays.toList()..sort(),
      heat: _heat,
      temperature: _temperature.round().toString(),
      steeringWheelHeat: _steeringWheelHeat,
    );
    final newControls = [..._schedule, entry];
    await _run('Guardar horario', () => widget.client.setPrepareCarSchedule(widget.vehicle.vin, widget.pin, newControls));
  }

  Future<void> _removeEntry(int index) async {
    final newControls = List<Map<String, dynamic>>.from(_schedule)..removeAt(index);
    await _run('Eliminar entrada', () => widget.client.setPrepareCarSchedule(widget.vehicle.vin, widget.pin, newControls));
  }

  String _describeEntry(Map<String, dynamic> entry) {
    final t = AppLocalizations.of(context)!;
    final dayNames = [t.dayShortSun, t.dayShortMon, t.dayShortTue, t.dayShortWed, t.dayShortThu, t.dayShortFri, t.dayShortSat];
    final startTime = entry['start_time']?.toString() ?? '--';
    final days = (entry['days'] as List?)?.cast<dynamic>() ?? [];
    final daysLabel = days.isEmpty ? t.onceLabel : days.map((d) => dayNames[(d as num).toInt()]).join(', ');
    final ac = (entry['datacontent'] as Map?)?['air_condition'] as Map?;
    final mode = ac?['mode'] == 'hot' ? t.heatChip : t.coldChip;
    final temp = ac?['temperature']?.toString() ?? '--';
    return '$startTime — $daysLabel — $mode $temp°C';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final dayNames = [t.dayShortSun, t.dayShortMon, t.dayShortTue, t.dayShortWed, t.dayShortThu, t.dayShortFri, t.dayShortSat];
    return Scaffold(
      appBar: AppBar(title: Text(t.preconditioningScreenTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(
                AppLocalizations.of(context)!.experimentalScheduleWarning,
                style: const TextStyle(fontSize: 12, color: Colors.amber),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!, style: const TextStyle(color: Colors.amber))),

            Text(AppLocalizations.of(context)!.modeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(children: [
              ChoiceChip(label: Text(AppLocalizations.of(context)!.heatChip), selected: _heat, onSelected: (v) => setState(() => _heat = true)),
              const SizedBox(width: 8),
              ChoiceChip(label: Text(AppLocalizations.of(context)!.coldChip), selected: !_heat, onSelected: (v) => setState(() => _heat = false)),
            ]),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.temperatureLabel(_temperature.round())),
            Slider(value: _temperature, min: 16, max: 32, divisions: 16, label: '${_temperature.round()}°C',
                onChanged: (v) => setState(() => _temperature = v)),
            SwitchListTile(
              value: _steeringWheelHeat,
              onChanged: (v) => setState(() => _steeringWheelHeat = v),
              title: Text(AppLocalizations.of(context)!.steeringWheelHeatToggle),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.bolt),
              label: Text(AppLocalizations.of(context)!.prepareNowButton),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _prepareNow,
            ),

            const Divider(height: 32),
            Text(AppLocalizations.of(context)!.scheduleSectionTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.hourLabel(_time.format(context))),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
            ),
            Text(AppLocalizations.of(context)!.daysNoneSelectedHint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) => FilterChip(
                    label: Text(dayNames[i]),
                    selected: _selectedDays.contains(i),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _selectedDays.add(i);
                      } else {
                        _selectedDays.remove(i);
                      }
                    }),
                  )),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_alarm),
              label: Text(AppLocalizations.of(context)!.addToScheduleButton),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _addScheduleEntry,
            ),

            const Divider(height: 32),
            Text(AppLocalizations.of(context)!.scheduledEntriesTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_schedule.isEmpty)
              Text(AppLocalizations.of(context)!.noScheduledEntries, style: const TextStyle(color: Colors.grey))
            else
              ..._schedule.asMap().entries.map((e) => Card(
                    child: ListTile(
                      title: Text(_describeEntry(e.value)),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _removeEntry(e.key)),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
