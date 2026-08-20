// maintenance_ticket.dart — Informe de mantenimiento imprimible/compartible.
//
// Mismo formato que ticket_printer.dart: 32 columnas monoespaciadas, pensado
// para RawBT/impresora termica pero legible tambien como captura de pantalla
// o PDF compartido. Reutiliza Mantenimiento.estado()/cargar(), no reinventa
// ningun calculo.

import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';

import 'energy_cost.dart';
import 'maintenance.dart';

const int _colsMant = 32;

String _line(String s) => s.length > _colsMant ? s.substring(0, _colsMant) : s;
String _center(String s) {
  if (s.length >= _colsMant) return s.substring(0, _colsMant);
  return ' ' * ((_colsMant - s.length) ~/ 2) + s;
}
String _sep() => '-' * _colsMant;
String _sep2() => '=' * _colsMant;
String _dmy(DateTime d) =>
    d.day.toString().padLeft(2, '0') + '/' +
    d.month.toString().padLeft(2, '0') + '/' +
    d.year.toString();

/// Informe completo de mantenimiento: los 10 elementos con su intervalo,
/// ultima intervencion anotada (o "Sin anotar", nunca una fecha inventada),
/// cuanto falta, e importe si se anoto. Cierra con un resumen y el gasto
/// anual ya calculado en energy_cost.dart.
Future<String> buildMaintenanceTicket({String? nickname}) async {
  final ahora = DateTime.now();
  var odo = 0;
  try {
    odo = int.tryParse(
            (await HomeWidget.getWidgetData<String>('odometro')) ?? '') ??
        0;
  } catch (_) {}

  final estados = await Mantenimiento.estado(odo);
  final registros = await Mantenimiento.cargar();

  final b = StringBuffer();
  b.writeln(_center('INFORME DE'));
  b.writeln(_center('MANTENIMIENTO'));
  b.writeln(_sep2());
  if (nickname != null && nickname.trim().isNotEmpty) {
    b.writeln(_center(nickname.trim()));
  }
  b.writeln(_line('Emitido: ' + _dmy(ahora)));
  if (odo > 0) b.writeln(_line('Odometro: ' + odo.toString() + ' km'));
  b.writeln(_sep2());
  b.writeln('');

  var vencidos = 0;
  EstadoMant? proximo;

  for (final e in estados) {
    b.writeln(_line(e.item.nombre));
    b.writeln(_sep());

    final partes = <String>[];
    if (e.item.km > 0) partes.add(e.item.km.toString() + ' km');
    if (e.item.meses > 0) {
      partes.add(e.item.meses >= 12
          ? (e.item.meses ~/ 12).toString() + ' anos'
          : e.item.meses.toString() + ' meses');
    }
    b.writeln(_line('  Cada ' + partes.join(' o ')));

    final reg = registros[e.item.id];
    if (reg == null) {
      b.writeln(_line('  Ultima: Sin anotar'));
    } else {
      final piezas = <String>[];
      if (reg.fechaMs > 0) {
        piezas.add(_dmy(DateTime.fromMillisecondsSinceEpoch(reg.fechaMs)));
      }
      if (reg.km > 0) piezas.add(reg.km.toString() + ' km');
      b.writeln(_line('  Ultima: ' + (piezas.isEmpty ? 'Sin anotar' : piezas.join(', '))));
      if (reg.importe != null) {
        b.writeln(_line('  Importe: ' + reg.importe!.toStringAsFixed(2) + ' EUR'));
      }
    }

    if (!e.sinDatos) {
      if (e.vencido) {
        b.writeln(_line('  VENCIDO'));
        vencidos++;
      } else {
        final restos = <String>[];
        if (e.kmRestantes != null) restos.add(e.kmRestantes.toString() + ' km');
        if (e.diasRestantes != null) {
          final d = e.diasRestantes!;
          restos.add(d > 60 ? (d ~/ 30).toString() + ' meses' : d.toString() + ' dias');
        }
        if (restos.isNotEmpty) {
          b.writeln(_line('  Faltan: ' + restos.join(' o ')));
        }
      }
    }
    b.writeln('');

    proximo ??= (!e.sinDatos && !e.vencido) ? e : proximo;
  }

  b.writeln(_sep2());
  b.writeln(_center('RESUMEN'));
  b.writeln(_sep());
  b.writeln(_line('Vencidos: ' + vencidos.toString()));
  if (proximo != null) {
    final p = proximo;
    final restos = <String>[];
    if (p.kmRestantes != null) restos.add(p.kmRestantes.toString() + ' km');
    if (p.diasRestantes != null) restos.add(p.diasRestantes.toString() + ' dias');
    b.writeln(_line('Proximo: ' + p.item.nombre));
    if (restos.isNotEmpty) b.writeln(_line('  (' + restos.join(' o ') + ')'));
  }
  try {
    final gasto = await gastoAnual();
    if (gasto > 0) {
      b.writeln(_line('Gasto anotado este ano:'));
      b.writeln(_line('  ' + gasto.toStringAsFixed(2) + ' EUR'));
    }
  } catch (_) {}
  b.writeln(_sep2());
  b.writeln('');
  b.writeln(_center('LMB10 - no oficial'));

  return b.toString();
}

/// Genera el fichero de texto y abre el dialogo de compartir del sistema,
/// exactamente igual que hace ticket_printer.dart.
Future<void> shareMaintenanceTicket({String? nickname}) async {
  final texto = await buildMaintenanceTicket(nickname: nickname);
  final dir = Directory.systemTemp;
  final f = File('${dir.path}/mantenimiento_lmb10.txt');
  await f.writeAsString(texto);
  await Share.shareXFiles([XFile(f.path)], text: 'Mantenimiento LMB10');
}
