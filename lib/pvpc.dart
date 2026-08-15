// Precios horarios PVPC desde la API publica de Red Electrica (REData).
//
// Por que hace falta: quien tiene tarifa regulada paga un precio distinto cada
// hora, asi que un precio unico no le sirve. Los precios del dia siguiente se
// publican hacia las 20:15.
//
// AVISO SOBRE EL DATO: el indicador 1001 de REData ya viene con peajes, cargos,
// impuesto electrico e IVA incluidos, es decir el PVPC final al consumidor. NO
// hay que sumarle nada. El indicador 10391 de ESIOS, en cambio, es solo el
// termino de energia; si algun dia se cambia de fuente, ojo con eso.
//
// El bono social aplica un descuento sobre el total que la API no conoce, asi
// que se ofrece un porcentaje configurable.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'car_log_bridge.dart';

const _pvpcStore = FlutterSecureStorage();
const _kCache = 'lm_pvpc_cache_v1';
const _kDto = 'lm_pvpc_dto_v1';
const _kVentana = 'lm_carga_ventana_v1';
const _kTermLitros = 'lm_term_litros_v1';
const _kTermPrecio = 'lm_term_precio_v1';

/// SOLO PENINSULA. El parametro geo_limit no altera la respuesta de este
/// endpoint. Para Canarias, Baleares o Ceuta y Melilla haria falta otra
/// fuente, sin identificar, asi que a esos usuarios NO hay que ofrecerles
/// esta opcion como si fuera la suya.
const kPvpcSoloPeninsula = true;

class PvpcDia {
  /// Clave 'YYYY-MM-DD', valor: 24 precios en EUR/kWh, indice = hora local.
  final String fecha;
  final List<double> horas;
  const PvpcDia(this.fecha, this.horas);

  Map<String, dynamic> toMap() => {'fecha': fecha, 'horas': horas};
  static PvpcDia? fromMap(Map<String, dynamic> m) {
    final f = m['fecha'] as String?;
    final h = m['horas'];
    if (f == null || h is! List || h.length != 24) return null;
    return PvpcDia(f, h.map((e) => (e as num).toDouble()).toList());
  }
}

class Pvpc {
  static String _hoy(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Descuento del bono social, en porcentaje. 0 = sin descuento.
  static Future<double> descuento() async =>
      double.tryParse(await _pvpcStore.read(key: _kDto) ?? '') ?? 0;

  static Future<void> setDescuento(double pct) =>
      _pvpcStore.write(key: _kDto, value: pct.toString());

  /// Ventana habitual de carga, "HH:MM-HH:MM", o vacio si no se usa.
  ///
  /// Hace falta porque la app NO sabe a que hora se cargo: el TCU duerme a los
  /// ~13 minutos, asi que entre la ultima muestra de la tarde y la primera de
  /// la manana no hay nada. Los timestamps de una carga son los de esas dos
  /// observaciones, no los de la carga real. Promediar precios de esa franja
  /// mete horas en las que el coche no estaba cargando y da precios absurdos
  /// (se vieron medias de 0,01 EUR/kWh).
  ///
  /// Con la ventana declarada por el usuario se promedian SOLO sus horas.
  static Future<String> ventana() async =>
      (await _pvpcStore.read(key: _kVentana)) ?? '';

  static Future<void> setVentana(String v) =>
      _pvpcStore.write(key: _kVentana, value: v);

  /// Consumo y precio del termico con el que comparar, para el informe.
  static Future<({double litros, double precio})> termico() async => (
        litros: double.tryParse(await _pvpcStore.read(key: _kTermLitros) ?? '') ?? 0,
        precio: double.tryParse(await _pvpcStore.read(key: _kTermPrecio) ?? '') ?? 0,
      );

  static Future<void> setTermico(double litros, double precio) async {
    await _pvpcStore.write(key: _kTermLitros, value: litros.toString());
    await _pvpcStore.write(key: _kTermPrecio, value: precio.toString());
  }

  static Future<Map<String, PvpcDia>> _cache() async {
    try {
      final raw = await _pvpcStore.read(key: _kCache);
      if (raw == null || raw.isEmpty) return {};
      final out = <String, PvpcDia>{};
      for (final e in (json.decode(raw) as List)) {
        final d = PvpcDia.fromMap(Map<String, dynamic>.from(e as Map));
        if (d != null) out[d.fecha] = d;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _guardarCache(Map<String, PvpcDia> c) async {
    // Solo se conservan 60 dias: el historico completo no cabe y tampoco sirve,
    // las cargas viejas ya tienen su coste calculado.
    final claves = c.keys.toList()..sort();
    final recorte = claves.length > 60
        ? claves.sublist(claves.length - 60)
        : claves;
    await _pvpcStore.write(
        key: _kCache,
        value: json.encode(recorte.map((k) => c[k]!.toMap()).toList()));
  }

  /// Precios de un dia. Del cache si estan; si no, se piden a REE.
  ///
  /// Devuelve null si no hay datos: para dias futuros mas alla de manana, o si
  /// la peticion falla. Quien llame debe caer al precio fijo, NO inventarse uno.
  static Future<PvpcDia?> dia(DateTime fecha, {bool permitirRed = true}) async {
    final clave = _hoy(fecha);
    final c = await _cache();
    if (c.containsKey(clave)) return c[clave];
    if (!permitirRed) return null;

    try {
      // Se pide el dia completo en hora local. REData devuelve los tramos con
      // su marca de tiempo, asi que el cambio de hora se resuelve solo.
      final uri = Uri.parse(
          'https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real'
          '?start_date=${clave}T00:00&end_date=${clave}T23:59'
          '&time_trunc=hour');
      final r = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        await CarLogBridge.log('PVPC HTTP ${r.statusCode} pidiendo ' + clave);
        return null;
      }
      final body = json.decode(r.body) as Map<String, dynamic>;
      final incluidos = body['included'] as List?;
      if (incluidos == null || incluidos.isEmpty) return null;

      // Se busca la serie del PVPC. El nombre exacto varia segun la version de
      // la API, asi que se filtra por contenido en vez de por posicion fija.
      List? valores;
      for (final s in incluidos) {
        final m = Map<String, dynamic>.from(s as Map);
        final tipo = (m['type'] ?? '').toString().toUpperCase();
        if (tipo.contains('PVPC')) {
          valores = ((m['attributes'] as Map?)?['values']) as List?;
          break;
        }
      }
      valores ??= ((Map<String, dynamic>.from(incluidos.first as Map)['attributes']
          as Map?)?['values']) as List?;
      if (valores == null || valores.isEmpty) return null;

      // El endpoint es de TIEMPO REAL: puede devolver el dia siguiente aunque
      // se pida otro. Cada valor se archiva bajo la fecha de su propio
      // datetime, no bajo la que se pidio.
      final porFecha = <String, List<double>>{};
      final vistasPorFecha = <String, int>{};
      for (final v in valores) {
        final m = Map<String, dynamic>.from(v as Map);
        final ts = DateTime.tryParse((m['datetime'] ?? '').toString());
        final val = m['value'];
        if (ts == null || val is! num) continue;
        final local = ts.toLocal();
        final k = _hoy(local);
        porFecha.putIfAbsent(k, () => List<double>.filled(24, 0));
        // REData da EUR/MWh.
        porFecha[k]![local.hour] = val.toDouble() / 1000.0;
        vistasPorFecha[k] = (vistasPorFecha[k] ?? 0) + 1;
      }

      // Se cachean TODOS los dias que hayan venido, no solo el pedido: si la
      // respuesta trae el de manana, aprovecharlo evita otra peticion.
      PvpcDia? pedido;
      for (final e in porFecha.entries) {
        if ((vistasPorFecha[e.key] ?? 0) < 20) continue;
        final dd = PvpcDia(e.key, e.value);
        c[e.key] = dd;
        if (e.key == clave) pedido = dd;
      }
      if (porFecha.isNotEmpty) await _guardarCache(c);

      if (pedido == null) {
        await CarLogBridge.log('PVPC pedido ' + clave + ' pero llegaron ' +
            porFecha.keys.join(',') );
        return null;
      }
      final d = pedido;
      return d;
    } catch (e) {
      await CarLogBridge.log('PVPC excepcion pidiendo ' + clave + ': ' + e.toString());
      return null;
    }
  }

  /// Precio medio ponderado de una franja, aplicando el descuento configurado.
  ///
  /// Es una APROXIMACION: se reparte la energia de forma uniforme entre la hora
  /// de inicio y la de fin. El coche no dice cuantos kWh entraron en cada hora,
  /// asi que no hay forma de hacerlo exacto. Una carga lenta nocturna se acerca
  /// bastante; una rapida que empiece al final de una hora, menos.
  static Future<double?> precioFranja(DateTime ini, DateTime fin) async {
    if (!fin.isAfter(ini)) {
      await CarLogBridge.log('PVPC franja invalida');
      return null;
    }

    // Si el usuario ha declarado su ventana de carga, se usa esa en vez de la
    // franja observada: los timestamps de la carga son cuando la app se
    // entero, no cuando el coche cargaba. Ver el comentario de ventana().
    final vent = await ventana();
    if (vent.contains('-')) {
      final p2 = vent.split('-');
      final h1 = int.tryParse(p2[0].split(':').first);
      final h2 = int.tryParse(p2[1].split(':').first);
      if (h1 != null && h2 != null && h1 != h2) {
        final base = DateTime(ini.year, ini.month, ini.day);
        ini = base.add(Duration(hours: h1));
        // Ventana que cruza medianoche: la de fin es del dia siguiente.
        fin = h2 > h1
            ? base.add(Duration(hours: h2))
            : base.add(Duration(days: 1, hours: h2));
        await CarLogBridge.log('PVPC usando ventana ' + vent);
      }
    }
    final dias = <String, PvpcDia>{};
    for (var t = DateTime(ini.year, ini.month, ini.day);
        !t.isAfter(DateTime(fin.year, fin.month, fin.day));
        t = t.add(const Duration(days: 1))) {
      final d = await dia(t);
      if (d == null) {
        await CarLogBridge.log('PVPC sin datos para ' + _hoy(t));
        return null;
      }
      dias[_hoy(t)] = d;
    }

    var suma = 0.0;
    var minutos = 0;
    var t = ini;
    while (t.isBefore(fin)) {
      final finHora = DateTime(t.year, t.month, t.day, t.hour).add(const Duration(hours: 1));
      final corte = finHora.isBefore(fin) ? finHora : fin;
      final m = corte.difference(t).inMinutes;
      final d = dias[_hoy(t)];
      if (d != null && m > 0) {
        suma += d.horas[t.hour] * m;
        minutos += m;
      }
      t = corte;
    }
    if (minutos == 0) {
      await CarLogBridge.log('PVPC 0 minutos en la franja');
      return null;
    }
    final medio = suma / minutos;
    final dto = await descuento();
    final res = dto > 0 ? medio * (1 - dto / 100.0) : medio;
    await CarLogBridge.log('PVPC ok ' + _hoy(ini) + ' ' +
        ini.hour.toString() + 'h-' + fin.hour.toString() + 'h medio=' +
        medio.toStringAsFixed(4) + ' dto=' + dto.toString() +
        ' final=' + res.toStringAsFixed(4));
    return res;
  }

  /// Resumen para el widget de precios: precio de ahora, mejor y peor hora
  /// del dia, y si la mejor hora ya paso y hay que mirar a manana. Se
  /// muestra siempre, tenga o no el usuario PVPC activado: son datos
  /// publicos del mercado, utiles por si solos.
  static Future<Map<String, dynamic>?> resumenWidget() async {
    final ahora = DateTime.now();
    final hoyDia = await dia(ahora);
    if (hoyDia == null) return null;
    final dto = await descuento();
    double conDto(double v) => dto > 0 ? v * (1 - dto / 100.0) : v;

    final horasHoy = hoyDia.horas.map(conDto).toList();
    final precioAhora = horasHoy[ahora.hour];

    // Horas de hoy que aun no han pasado, incluyendo la actual.
    final restantes = List.generate(24, (i) => i)
        .where((h) => h >= ahora.hour)
        .toList();

    int horaBarata;
    double precioBarato;
    var esManana = false;
    if (restantes.length > 1) {
      horaBarata = restantes
          .reduce((a, b) => horasHoy[a] <= horasHoy[b] ? a : b);
      precioBarato = horasHoy[horaBarata];
    } else {
      final mh = await mejoresHoras(1);
      final mananaDia = await dia(ahora.add(const Duration(days: 1)));
      if (mh != null && mh.isNotEmpty && mananaDia != null) {
        horaBarata = mh.first;
        precioBarato = conDto(mananaDia.horas[horaBarata]);
        esManana = true;
      } else {
        horaBarata = ahora.hour;
        precioBarato = precioAhora;
      }
    }

    var horaCara = 0;
    for (var h = 1; h < 24; h++) {
      if (horasHoy[h] > horasHoy[horaCara]) horaCara = h;
    }

    // Nivel relativo al propio dia: los precios cambian mucho por temporada,
    // asi que un umbral fijo en EUR no tendria sentido todo el año.
    final minHoy = horasHoy.reduce((a, b) => a < b ? a : b);
    final maxHoy = horasHoy.reduce((a, b) => a > b ? a : b);
    final rango = maxHoy - minHoy;
    String nivel;
    if (rango < 0.02) {
      nivel = 'normal';
    } else {
      final pos = (precioAhora - minHoy) / rango;
      nivel = pos < 0.33 ? 'barato' : (pos > 0.66 ? 'caro' : 'normal');
    }

    return {
      'ahora': precioAhora,
      'nivel': nivel,
      'horaBarata': horaBarata,
      'precioBarato': precioBarato,
      'baratoEsManana': esManana,
      'horaCara': horaCara,
      'precioCaro': horasHoy[horaCara],
    };
  }

  /// Las N horas mas baratas de manana, para saber cuando enchufar.
  static Future<List<int>?> mejoresHoras(int cuantas) async {
    final d = await dia(DateTime.now().add(const Duration(days: 1)));
    if (d == null) return null;
    final idx = List.generate(24, (i) => i)
      ..sort((a, b) => d.horas[a].compareTo(d.horas[b]));
    return idx.take(cuantas).toList()..sort();
  }
}
