// routines_background.dart — Evaluacion de rutinas programadas en segundo
// plano. Llamar desde el callback de WorkManager (~15 min). Ejecuta una
// rutina si su hora ya paso dentro de la ultima ventana y hoy es un dia
// valido, evitando repetirla el mismo dia (marca lm_routine_lastrun_<id>).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../leapmotor_engine.dart';
import 'routine_engine.dart';

const _bgStorage = FlutterSecureStorage();

Future<void> routinesBackgroundTick(
    LeapmotorApiClient client, String vin, String pin,
    {VehicleStatus? status}) async {
  if (pin.isEmpty) return; // sin PIN no hay comandos en fondo
  final now = DateTime.now();
  final weekday = now.weekday; // 1=Lun ... 7=Dom
  final routines = await RoutineStore.load();
  final engine = RoutineEngine(client: client, vin: vin, pin: pin);

  for (final r in routines) {
    if (!r.enabled || !r.isScheduled) continue;
    if (r.scheduleDays.isNotEmpty && !r.scheduleDays.contains(weekday)) continue;

    final sched = DateTime(now.year, now.month, now.day, r.scheduleHour!,
        r.scheduleMinute ?? 0);
    // Disparar si la hora ya paso hoy pero por menos de 30 min (ventana de
    // WorkManager) y no se ejecuto ya hoy.
    final diff = now.difference(sched).inMinutes;
    if (diff < 0 || diff > 30) continue;

    final key = 'lm_routine_lastrun_${r.id}';
    final last = await _bgStorage.read(key: key);
    final today = '${now.year}-${now.month}-${now.day}';
    if (last == today) continue;

    await engine.run(r, status: status);
    await _bgStorage.write(key: key, value: today);
  }
}
