// Mantenimiento periodico del vehiculo.
//
// El coche NO reporta nada de esto: no hay fecha ni kilometros de proxima
// revision en el payload, solo totalMileage. Asi que los intervalos salen del
// manual y la ultima intervencion la anota el usuario.
//
// Intervalos del manual del B10 (pagina "Tabla de intervalo de mantenimiento").
// El propio manual advierte: "el tiempo y el kilometraje se basan en lo que
// ocurra primero".

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _mStore = FlutterSecureStorage();
const _kMant = 'lm_mantenimiento_v1';

class ItemMant {
  final String id;
  final String nombre;
  final String nombreEn;
  /// Kilometros entre intervenciones. 0 = solo por tiempo.
  final int km;
  /// Meses entre intervenciones. 0 = solo por kilometros.
  final int meses;
  final String nota;
  final String notaEn;
  /// Si tiene sentido preguntar cuanto costo, para el resumen de gastos.
  /// No aplica a cosas como las escobillas: nadie anota ese importe.
  final bool tieneCoste;

  const ItemMant(this.id, this.nombre, this.nombreEn, this.km, this.meses,
      this.nota, this.notaEn, {this.tieneCoste = false});
}

/// Los siete elementos con plazo definido en el manual. El resto de la tabla
/// son revisiones visuales que se hacen en cada mantenimiento y no tienen
/// ciclo propio, asi que no procede recordarlas por separado.
const kItemsMant = <ItemMant>[
  ItemMant('revision', 'Revision general', 'General service', 20000, 12,
      'Mantenimiento periodico completo en taller autorizado. Incluye bateria, '
          'frenos, chasis, motor y electronica.',
      'Full periodic service at an authorised dealer.'),
  ItemMant('filtro_ac', 'Filtro del aire acondicionado', 'A/C filter', 20000, 12,
      'Sustituir cada ano o 20.000 km. Si notas mal olor al usar el aire, '
          'cambialo antes.',
      'Replace yearly or every 20,000 km. Sooner if you notice bad smell.'),
  ItemMant('liquido_frenos', 'Liquido de frenos', 'Brake fluid', 40000, 24,
      'Sustituir cada 2 anos o 40.000 km. Absorbe humedad con el tiempo y eso '
          'reduce la eficacia del frenado. Solo en taller autorizado.',
      'Replace every 2 years or 40,000 km. Authorised dealer only.'),
  ItemMant('refrigerante', 'Refrigerante', 'Coolant', 40000, 48,
      'Sustituir cada 4 anos o 40.000 km. Debe ser de la misma especificacion '
          'que el original.',
      'Replace every 4 years or 40,000 km. Same spec as original.'),
  ItemMant('neumaticos', 'Neumaticos', 'Tyres', 40000, 36,
      'Sustitucion recomendada cada 3 anos o 40.000 km, o antes si el dibujo '
          'baja de 1,6 mm.',
      'Recommended every 3 years or 40,000 km, or sooner below 1.6 mm tread.'),
  ItemMant('aceite_reductor', 'Aceite del reductor', 'Reducer oil', 60000, 0,
      'Cambiar cada 60.000 km.',
      'Change every 60,000 km.'),
  ItemMant('filtro_reductor', 'Filtro del reductor', 'Reducer filter', 60000, 0,
      'Cambiar cada 60.000 km.',
      'Change every 60,000 km.'),
  ItemMant('limpiaparabrisas', 'Escobillas limpiaparabrisas', 'Wiper blades',
      0, 12,
      'Se recomienda sustituirlas cada ano de uso.',
      'Recommended yearly.'),
  ItemMant('seguro', 'Seguro del vehiculo', 'Vehicle insurance', 0, 12,
      'El coche no informa de esto: anota la fecha de tu ultima renovacion '
          'para no llegar tarde a la siguiente.',
      'The car reports nothing about this: note your last renewal date so '
          'you do not miss the next one.',
      tieneCoste: true),
  ItemMant('impuesto_circulacion', 'Impuesto de circulacion',
      'Road tax', 0, 12,
      'Se paga una vez al ano, normalmente entre marzo y abril segun el '
          'ayuntamiento. Consulta la fecha exacta en tu recibo del ano '
          'anterior.',
      'Paid once a year, usually spring, dates vary by municipality. Check '
          'your previous receipt for the exact date.',
      tieneCoste: true),
];

/// Ultima intervencion anotada por el usuario.
class RegistroMant {
  final String id;
  final int km;
  final int fechaMs;
  /// Cuanto costo esta renovacion, si el usuario lo anoto. Nulo en
  /// registros de mantenimiento normal (frenos, filtros...) o si no se
  /// quiso anotar el importe.
  final double? importe;
  const RegistroMant(this.id, this.km, this.fechaMs, {this.importe});

  Map<String, dynamic> toMap() =>
      {'id': id, 'km': km, 'fecha': fechaMs, 'importe': importe};
  static RegistroMant? fromMap(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is! String) return null;
    return RegistroMant(id, (m['km'] as num?)?.toInt() ?? 0,
        (m['fecha'] as num?)?.toInt() ?? 0,
        importe: (m['importe'] as num?)?.toDouble());
  }
}

/// Cuanto falta para la proxima intervencion.
///
/// Devuelve el menor de los dos plazos: el manual dice que vale "lo que ocurra
/// primero", asi que un coche que hace pocos kilometros llega antes por tiempo.
class EstadoMant {
  final ItemMant item;
  final int? kmRestantes;
  final int? diasRestantes;
  final bool vencido;
  final bool sinDatos;
  const EstadoMant(this.item,
      {this.kmRestantes, this.diasRestantes, this.vencido = false,
      this.sinDatos = false});

  /// Para ordenar por urgencia. Cuanto menor, mas urgente.
  double get urgencia {
    if (sinDatos) return 999999;
    if (vencido) return -1;
    final porKm = (item.km > 0 && kmRestantes != null)
        ? kmRestantes! / item.km
        : 999.0;
    final porTiempo = (item.meses > 0 && diasRestantes != null)
        ? diasRestantes! / (item.meses * 30.0)
        : 999.0;
    return porKm < porTiempo ? porKm : porTiempo;
  }
}

class Mantenimiento {
  static Future<Map<String, RegistroMant>> cargar() async {
    try {
      final raw = await _mStore.read(key: _kMant);
      if (raw == null || raw.isEmpty) return {};
      final out = <String, RegistroMant>{};
      for (final e in (json.decode(raw) as List)) {
        final r = RegistroMant.fromMap(Map<String, dynamic>.from(e as Map));
        if (r != null) out[r.id] = r;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> guardar(RegistroMant r) async {
    final all = await cargar();
    all[r.id] = r;
    await _mStore.write(
        key: _kMant,
        value: json.encode(all.values.map((e) => e.toMap()).toList()));
  }

  static Future<void> borrar(String id) async {
    final all = await cargar();
    all.remove(id);
    await _mStore.write(
        key: _kMant,
        value: json.encode(all.values.map((e) => e.toMap()).toList()));
  }

  /// Estado de todos los elementos, ordenados por urgencia.
  static Future<List<EstadoMant>> estado(int odometroActual) async {
    final reg = await cargar();
    final ahora = DateTime.now();
    final out = <EstadoMant>[];
    for (final it in kItemsMant) {
      final r = reg[it.id];
      if (r == null) {
        out.add(EstadoMant(it, sinDatos: true));
        continue;
      }
      int? kmRest;
      if (it.km > 0 && odometroActual > 0 && r.km > 0) {
        kmRest = r.km + it.km - odometroActual;
      }
      int? diasRest;
      if (it.meses > 0 && r.fechaMs > 0) {
        final proxima = DateTime.fromMillisecondsSinceEpoch(r.fechaMs)
            .add(Duration(days: (it.meses * 30.44).round()));
        diasRest = proxima.difference(ahora).inDays;
      }
      final venc = (kmRest != null && kmRest <= 0) ||
          (diasRest != null && diasRest <= 0);
      out.add(EstadoMant(it,
          kmRestantes: kmRest, diasRestantes: diasRest, vencido: venc));
    }
    out.sort((a, b) => a.urgencia.compareTo(b.urgencia));
    return out;
  }

  /// Resumen corto para el widget, o vacio si no hay nada que avisar.
  ///
  /// Solo habla cuando queda poco: un aviso permanente se deja de mirar.
  static Future<String> aviso(int odometroActual) async {
    final st = await estado(odometroActual);
    for (final e in st) {
      if (e.sinDatos) continue;
      if (e.vencido) return e.item.nombre + ': vencido';
      final km = e.kmRestantes;
      final d = e.diasRestantes;
      if (km != null && km <= 1000) {
        return e.item.nombre + ': faltan ' + km.toString() + ' km';
      }
      if (d != null && d <= 30) {
        return e.item.nombre + ': faltan ' + d.toString() + ' dias';
      }
    }
    return '';
  }
}
