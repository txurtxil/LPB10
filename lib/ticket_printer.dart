// ticket_printer.dart — Ticket termico de eficiencia del coche para RawBT.
//
// Formato: 32 columnas monoespaciadas, barras con bloque unicode.
// Datos del propio coche (no de Octopus): consumo kWh/100 km por dia +
// resumen de medias. Objetivo: ver de un vistazo que dias te pasas del
// objetivo de 15,6 kWh/100 (= 430 km por carga) para mejorar el consumo.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'charge_cost.dart';
import 'daily_stats.dart';
import 'energy_cost.dart';
import 'pvpc.dart';
import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

// Copias privadas que se quedaron fuera del perfil de vehiculo (ver
// efficiency_coach.dart). Getters para que reflejen el modelo elegido.
double get kTicketBatteryKwh => gBatteryKwh;
double get kTicketMaxRangeKm => gMaxRangeKm;
final double kTicketTarget = kTicketBatteryKwh / kTicketMaxRangeKm * 100.0; // 15,6

const int _cols = 32;


/// Informe de eficiencia y coste para el rango [from, to], inclusive por dia.
///
/// Reescrito para que sirva como justificante: identifica el vehiculo y el
/// periodo, detalla cargas y coste, y lleva notas metodologicas al pie. Sin
/// esas notas, cualquiera que revise el documento puede rebatirlo.
///
/// Antes leia las cargas de 'lm_charge_history_v1', el almacen de la deteccion
/// en vivo que NUNCA llego a funcionar, asi que siempre imprimia "Cargas: 0".
/// Ahora usa ChargeRebuild.fromTrips() como el resto de la app.
Future<String> buildEfficiencyTicket({
  required DateTime from,
  required DateTime to,
  String? nickname,
}) async {
  final agg = await DailyStats.load();
  final d0 = DateTime(from.year, from.month, from.day);
  final d1 = DateTime(to.year, to.month, to.day);
  final desde = DailyStats.dayKey(d0);
  final hasta = DailyStats.dayKey(d1);
  final dias = agg.where((a) => a.d.compareTo(desde) >= 0 && a.d.compareTo(hasta) <= 0)
      .toList()
    ..sort((a, b) => a.d.compareTo(b.d));

  final precios = await preciosPorDia();
  final tot = totalizar(dias, precios);

  final todasCargas = await ChargeRebuild.fromTrips();
  final costes = await ChargeCostStore.loadAll();
  final cargas = todasCargas.where((c) {
    final t = DateTime.fromMillisecondsSinceEpoch(c.endTs);
    return !DateTime(t.year, t.month, t.day).isBefore(d0) &&
        !DateTime(t.year, t.month, t.day).isAfter(d1);
  }).toList();

  final b = StringBuffer();
  String line(String s) => s.length > _cols ? s.substring(0, _cols) : s;
  String center(String s) {
    if (s.length >= _cols) return s.substring(0, _cols);
    return ' ' * ((_cols - s.length) ~/ 2) + s;
  }
  String sep() => '-' * _cols;
  String sep2() => '=' * _cols;
  String dm(DateTime d) =>
      d.day.toString().padLeft(2, '0') + '/' + d.month.toString().padLeft(2, '0');
  String dmy(DateTime d) => dm(d) + '/' + d.year.toString();

  final ahora = DateTime.now();

  // ---------- IDENTIFICACION ----------
  b.writeln(center('INFORME DE USO Y COSTE'));
  b.writeln(center('VEHICULO ELECTRICO'));
  if (nickname != null && nickname.trim().isNotEmpty) {
    b.writeln(center(nickname.trim()));
  }
  b.writeln(sep2());
  b.writeln(_kv('Periodo:', dm(d0) + ' a ' + dm(d1)));
  b.writeln(_kv('Dias:', (d1.difference(d0).inDays + 1).toString()));
  b.writeln(_kv('Bateria:', _d1(kTicketBatteryKwh) + ' kWh'));
  b.writeln(_kv('Autonomia cat.:', kTicketMaxRangeKm.round().toString() + ' km'));
  b.writeln(_kv('Objetivo:', _d1(kTicketTarget) + ' kWh/100'));
  b.writeln(sep2());
  b.writeln('');

  // ---------- CONSUMO POR DIA ----------
  b.writeln(line('CONSUMO DIARIO'));
  b.writeln(sep());

  final conDato = <DayAgg>[];
  for (final a in dias) {
    if (a.km >= DailyStats.kMinKm && a.soc > 0) {
      final v = a.soc / a.km * 100.0;
      if (v >= DailyStats.kSegMin && v <= DailyStats.kSegMax) conDato.add(a);
    }
  }
  double kwh100De(DayAgg a) => a.soc / a.km * gBatteryKwh;

  final maxVal = conDato.isEmpty
      ? kTicketTarget
      : conDato.map(kwh100De).reduce((x, y) => x > y ? x : y);
  const barMax = 7;

  DayAgg? mejor, peor;
  for (final a in dias) {
    final dt = DateTime.tryParse(a.d);
    final et = dt == null ? a.d : dm(dt);
    if (!conDato.contains(a)) {
      b.writeln(line(et + '            --'));
      continue;
    }
    final v = kwh100De(a);
    mejor = (mejor == null || v < kwh100De(mejor)) ? a : mejor;
    peor = (peor == null || v > kwh100De(peor)) ? a : peor;
    final blocks = maxVal <= 0 ? 0 : (v / maxVal * barMax).round().clamp(0, barMax);
    final bar = '\u2588' * blocks + ' ' * (barMax - blocks);
    b.writeln(line(et + ' ' + bar + ' ' + _pad5(v) + (v > kTicketTarget ? '>' : ' ')));
  }
  b.writeln(line('> = por encima del objetivo'));
  b.writeln('');

  // ---------- RESUMEN ----------
  b.writeln(line('RESUMEN DEL PERIODO'));
  b.writeln(sep());
  b.writeln(_kv('Distancia:', tot.km.round().toString() + ' km'));
  b.writeln(_kv('Energia:', _d1(tot.kwh) + ' kWh'));
  // OJO: tot.kwh son los kWh de los tramos que pasan los filtros de consumo,
  // pero tot.km son TODOS los kilometros. Dividir uno entre otro mezcla dos
  // poblaciones y da cifras imposibles (se vio 10,7 kWh/100 en un B10).
  // La media se calcula solo con los dias de dato valido y su km filtrado.
  var kmMedia = 0.0, socMedia = 0.0;
  for (final a in conDato) {
    kmMedia += a.km;
    socMedia += a.soc;
  }
  final media =
      kmMedia > 0 ? socMedia / kmMedia * gBatteryKwh : null;
  b.writeln(_kv('Consumo medio:', media == null ? '--' : _d1(media) + ' kWh/100'));
  if (media != null) {
    final desv = (media - kTicketTarget) / kTicketTarget * 100.0;
    b.writeln(_kv('Frente a objetivo:',
        (desv >= 0 ? '+' : '') + _d1(desv) + ' %'));
    b.writeln(_kv('Autonomia real:',
        (kTicketBatteryKwh / media * 100).round().toString() + ' km'));
  }
  if (mejor != null) {
    final dt = DateTime.tryParse(mejor.d);
    b.writeln(_kv('Mejor dia:',
        (dt == null ? mejor.d : dm(dt)) + '  ' + _d1(kwh100De(mejor))));
  }
  if (peor != null) {
    final dt = DateTime.tryParse(peor.d);
    b.writeln(_kv('Peor dia:',
        (dt == null ? peor.d : dm(dt)) + '  ' + _d1(kwh100De(peor))));
  }
  b.writeln('');

  // ---------- CARGAS ----------
  b.writeln(line('CARGAS DEL PERIODO'));
  b.writeln(sep());
  if (cargas.isEmpty) {
    b.writeln(line('Sin cargas registradas.'));
  } else {
    final cfgPrecio = await EnergyPrice.load();
    final precioCasa = cfgPrecio?.eurKwh;
    final esPvpc = cfgPrecio?.esPvpc ?? false;
    var kwhCargado = 0.0, pagado = 0.0;
    var hayImporte = false;
    for (final c in cargas) {
      final t = DateTime.fromMillisecondsSinceEpoch(c.endTs);
      final k = c.kwh;
      kwhCargado += k;
      final m = costes[c.startTs];
      String imp = '';
      var estimado = false;
      // Con PVPC activo y sin importe manual anotado, se usa el precio de la
      // franja de ESA carga -- la misma logica que ya aplica preciosPorDia()
      // para el resumen, para que las dos cifras del ticket coincidan.
      var precioEfectivo = precioCasa;
      if (esPvpc && (m == null || (m.eur == null && m.eurKwh == null))) {
        precioEfectivo = await Pvpc.precioFranja(
                DateTime.fromMillisecondsSinceEpoch(c.startTs), t) ??
            precioCasa;
      }
      final coste = costeCarga(
        kwhBateria: k,
        manual: m,
        precioCasa: precioEfectivo,
        marca: (e) => estimado = e,
      );
      if (coste != null) {
        pagado += coste;
        hayImporte = true;
        imp = (estimado ? '~' : '') + _d2(coste) + 'E';
      }
      b.writeln(line(dm(t) + '  ' +
          c.startSoc.round().toString().padLeft(3) + '>' +
          c.endSoc.round().toString().padLeft(3) + '%  ' +
          (_d1(k) + 'kWh').padLeft(9)));
      if (imp.isNotEmpty) b.writeln(_kv('', imp));
    }
    b.writeln(sep());
    b.writeln(_kv('Sesiones:', cargas.length.toString()));
    b.writeln(_kv('Energia cargada:', _d1(kwhCargado) + ' kWh'));
    if (hayImporte) b.writeln(_kv('Importe pagado:', _d2(pagado) + ' EUR'));
    if (kwhCargado > 0 && tot.kwh > 0) {
      final saldo = kwhCargado - tot.kwh;
      b.writeln('');
      b.writeln(line('Cargado ' + _d1(kwhCargado) + ' kWh, consumido'));
      b.writeln(line(_d1(tot.kwh) + ' kWh. Diferencia de'));
      b.writeln(line(_d1(saldo.abs()) + ' kWh ' +
          (saldo >= 0 ? 'que queda en bateria.' : 'que ya estaba en bateria.')));
    }
  }
  b.writeln('');

  // ---------- COSTE ----------
  if (tot.hayEur && tot.km > 0) {
    b.writeln(line('COSTE DE USO'));
    b.writeln(sep());
    b.writeln(_kv('Energia consumida:', _d2(tot.eur) + ' EUR'));
    final eurKm = tot.eur / tot.km;
    b.writeln(_kv('Coste por km:', _d3(eurKm) + ' EUR/km'));
    b.writeln(_kv('Coste por 100km:', _d2(eurKm * 100) + ' EUR'));
    b.writeln('');
    b.writeln(line('Calculado sobre la energia'));
    b.writeln(line('consumida en el periodo, no'));
    b.writeln(line('sobre lo cargado.'));
    // Referencia: un termico equivalente a 7 l/100 y 1,55 EUR/l son 10,85
    // EUR/100 km. Sirve para dimensionar el ahorro, no es una medida.
    // Cifras del termico que el usuario tenia antes, si las indico. Una
    // referencia generica no vale: un diesel de 5 l y un gasolina de 8 dan
    // ahorros muy distintos.
    final term = await Pvpc.termico();
    if (term.litros > 0 && term.precio > 0) {
      final ref100 = term.litros * term.precio;
      final ahorro = (ref100 - eurKm * 100) / 100.0 * tot.km;
      b.writeln('');
      b.writeln(line('COMPARATIVA'));
      b.writeln(sep());
      b.writeln(_kv('Termico ref.:', _d1(term.litros) + ' l/100'));
      b.writeln(_kv('Combustible:', _d3(term.precio) + ' EUR/l'));
      b.writeln(_kv('Termico 100km:', _d2(ref100) + ' EUR'));
      b.writeln(_kv('Electrico 100km:', _d2(eurKm * 100) + ' EUR'));
      b.writeln(sep());
      if (ahorro > 0) {
        b.writeln(_kv('AHORRO:', _d2(ahorro) + ' EUR'));
        b.writeln(_kv('Litros no gastados:',
            _d1(term.litros * tot.km / 100.0) + ' l'));
      } else {
        b.writeln(_kv('Sobrecoste:', _d2(-ahorro) + ' EUR'));
      }
    }
    b.writeln('');
  }

  // ---------- NOTAS ----------
  b.writeln(sep());
  b.writeln(line('NOTAS'));
  b.writeln(line('- Energia medida EN BATERIA, no'));
  b.writeln(line('  en el enchufe. La factura es'));
  b.writeln(line('  un 12-15% mayor por perdidas'));
  b.writeln(line('  de carga.'));
  b.writeln(line('- Las cargas se reconstruyen'));
  b.writeln(line('  del historico de bateria; el'));
  b.writeln(line('  fabricante no las publica.'));
  b.writeln(line('- Importes con ~ son estimados'));
  b.writeln(line('  con el precio configurado.'));
  b.writeln(line('- Dias sin datos suficientes'));
  b.writeln(line('  aparecen como --'));
  b.writeln(sep());
  b.writeln(line('Emitido: ' + dmy(ahora) + ' ' +
      ahora.hour.toString().padLeft(2, '0') + ':' +
      ahora.minute.toString().padLeft(2, '0')));
  b.writeln(line('LMB10 - app no oficial'));
  b.writeln(center('lmb10'));
  b.writeln('');
  b.writeln('');
  b.writeln('');
  return b.toString();
}

String _d1(num v) => v.toStringAsFixed(1).replaceAll('.', ',');
String _d2(num v) => v.toStringAsFixed(2).replaceAll('.', ',');
String _d3(num v) => v.toStringAsFixed(3).replaceAll('.', ',');
String _pad5(double v) => _d1(v).padLeft(5);
String _kv(String k, String v) {
  final avail = _cols - k.length;
  final val = v.length > avail ? v.substring(0, avail) : v;
  return k + val.padLeft(avail);
}

class TicketPrinter {
  static const _channel = MethodChannel('lmb10/rawbt');

  /// Intenta imprimir por RawBT. Si no esta o falla, abre la hoja de compartir.
  static Future<bool> printOrShare(String ticket) async {
    try {
      final ok = await _channel.invokeMethod<bool>('printRawBT', {'text': ticket});
      if (ok == true) return true;
    } catch (_) {}
    try {
      final dir = Directory.systemTemp;
      final f = File('${dir.path}/lmb10_ticket.txt');
      await f.writeAsString(ticket);
      await Share.shareXFiles([XFile(f.path)], text: 'Ticket LMB10');
      return true;
    } catch (_) {
      return false;
    }
  }
}
