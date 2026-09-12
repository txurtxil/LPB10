import 'package:flutter/material.dart';
import 'leapmotor_engine.dart';
import 'pvpc.dart';
import 'l10n/generated/app_localizations.dart';

class ChargeScheduleScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  final String pin;
  const ChargeScheduleScreen({super.key, required this.client, required this.vehicle, required this.pin});

  @override
  State<ChargeScheduleScreen> createState() => _ChargeScheduleScreenState();
}

class _ChargeScheduleScreenState extends State<ChargeScheduleScreen> {
  bool _busy = false;
  bool _loading = true;
  String? _message;

  bool _enabled = false;
  double _socLimit = 80;
  int _duracionPvpc = 4;
  bool _pvpcBuscando = false;
  String? _pvpcInfo;
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 7, minute: 0);
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5, 6, 7};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final schedule = await widget.client.getChargeSchedule(widget.vehicle.vin);
      if (schedule.isNotEmpty) {
        setState(() {
          _enabled = (schedule['chargeEnable'] == 1 || schedule['chargeEnable'] == true);
          _socLimit = ((schedule['chargesoc'] as num?)?.toDouble() ?? 80).clamp(50, 100);
          final cycles = schedule['cycles']?.toString().split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
          if (cycles != null && cycles.isNotEmpty) {
            _selectedWeekdays
              ..clear()
              ..addAll(cycles);
          }
          _startTime = _parseTime(schedule['starttime']?.toString()) ?? _startTime;
          _endTime = _parseTime(schedule['endtime']?.toString()) ?? _endTime;
        });
      }
    } catch (_) {
      // Sin horario previo o error de lectura: se dejan los valores por defecto.
    } finally {
      setState(() => _loading = false);
    }
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Rellena inicio/fin con la ventana contigua mas barata del PVPC de
  /// manana. NO guarda nada: el usuario revisa y pulsa Guardar como siempre.
  Future<void> _sugerirPvpc() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    setState(() {
      _pvpcBuscando = true;
      _pvpcInfo = null;
    });
    try {
      final d = await Pvpc.dia(DateTime.now().add(const Duration(days: 1)));
      if (!mounted) return;
      if (d == null || d.horas.length != 24) {
        setState(() {
          _pvpcBuscando = false;
          _pvpcInfo = es
              ? 'Los precios de manana aun no estan publicados (se publican ~20:15).'
              : "Tomorrow's prices are not published yet (~20:15).";
        });
        return;
      }
      final (ini, fin) = cheapestWindowHours(d.horas, _duracionPvpc);
      var suma = 0.0, sumaDia = 0.0;
      for (var h = 0; h < 24; h++) {
        sumaDia += d.horas[h];
        if (h >= ini && h < fin) suma += d.horas[h];
      }
      final mediaVentana = suma / _duracionPvpc;
      final mediaDia = sumaDia / 24;
      setState(() {
        _startTime = TimeOfDay(hour: ini, minute: 0);
        _endTime = fin == 24 ? const TimeOfDay(hour: 23, minute: 59) : TimeOfDay(hour: fin, minute: 0);
        _pvpcBuscando = false;
        _pvpcInfo = es
            ? 'Ventana mas barata de manana: ${'$ini'}:00 - ${'$fin'}:00 · ${mediaVentana.toStringAsFixed(3)} EUR/kWh (media del dia: ${mediaDia.toStringAsFixed(3)}). Revisa y pulsa Guardar.'
            : 'Cheapest window tomorrow: $ini:00 - $fin:00 · ${mediaVentana.toStringAsFixed(3)} EUR/kWh (day average: ${mediaDia.toStringAsFixed(3)}). Review and tap Save.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pvpcBuscando = false;
        _pvpcInfo = es ? 'Error consultando PVPC: $e' : 'PVPC query failed: $e';
      });
    }
  }

  Future<void> _save() async {
    setState(() { _busy = true; _message = null; });
    try {
      await widget.client.setChargeSchedule(
        widget.vehicle.vin, widget.pin,
        enabled: _enabled,
        socLimit: _socLimit.round(),
        startTime: _fmtTime(_startTime),
        endTime: _fmtTime(_endTime),
        weekdays: _selectedWeekdays.toList()..sort(),
      );
      setState(() => _message = 'Horario guardado: OK');
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final weekdayNames = [t.dayShortMon, t.dayShortTue, t.dayShortWed, t.dayShortThu, t.dayShortFri, t.dayShortSat, t.dayShortSun];
    return Scaffold(
      appBar: AppBar(title: Text(t.chargeScheduleScreenTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      AppLocalizations.of(context)!.chargeScheduleExperimentalWarning,
                      style: const TextStyle(fontSize: 12, color: Colors.amber),
                    ),
                  ),
                  if (_busy) const LinearProgressIndicator(),
                  if (_message != null)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message!, style: const TextStyle(color: Colors.amber))),

                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.teal.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          Localizations.localeOf(context).languageCode == 'es'
                              ? 'Ventana barata PVPC (manana)'
                              : 'Cheapest PVPC window (tomorrow)',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final h in [2, 3, 4, 5, 6, 7, 8])
                              ChoiceChip(
                                label: Text('${h}h'),
                                selected: _duracionPvpc == h,
                                onSelected: (_) => setState(() => _duracionPvpc = h),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.bolt, size: 18),
                          label: Text(Localizations.localeOf(context).languageCode == 'es'
                              ? 'Sugerir ventana mas barata'
                              : 'Suggest cheapest window'),
                          onPressed: _pvpcBuscando ? null : _sugerirPvpc,
                        ),
                        if (_pvpcBuscando)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          ),
                        if (_pvpcInfo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_pvpcInfo!, style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: Text(AppLocalizations.of(context)!.scheduleActiveToggle),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.chargeLimitValue(_socLimit.round())),
                  Slider(
                    value: _socLimit, min: 50, max: 100, divisions: 10,
                    label: '${_socLimit.round()}%',
                    onChanged: (v) => setState(() => _socLimit = v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.startTimeLabel(_fmtTime(_startTime))),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(AppLocalizations.of(context)!.endTimeLabel(_fmtTime(_endTime))),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: _endTime);
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context)!.weekdaysTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      final weekday = i + 1; // 1=lunes .. 7=domingo
                      return FilterChip(
                        label: Text(weekdayNames[i]),
                        selected: _selectedWeekdays.contains(weekday),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _selectedWeekdays.add(weekday);
                          } else {
                            _selectedWeekdays.remove(weekday);
                          }
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(AppLocalizations.of(context)!.saveScheduleButton),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
    );
  }
}
