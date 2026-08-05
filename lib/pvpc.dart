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

const _pvpcStore = FlutterSecureStorage();
const _kCache = 'lm_pvpc_cache_v1';
const _kDto = 'lm_pvpc_dto_v1';

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
        debugPrint('PVPC HTTP ${r.statusCode}');
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
        debugPrint('PVPC pedido ' + clave + ' pero llegaron ' +
            porFecha.keys.join(',') );
        return null;
      }
      final d = pedido;
      return d;
    } catch (e) {
      debugPrint('PVPC fallo: $e');
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
    if (!fin.isAfter(ini)) return null;
    final dias = <String, PvpcDia>{};
    for (var t = DateTime(ini.year, ini.month, ini.day);
        !t.isAfter(DateTime(fin.year, fin.month, fin.day));
        t = t.add(const Duration(days: 1))) {
      final d = await dia(t);
      if (d == null) return null;
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
    if (minutos == 0) return null;
    final medio = suma / minutos;
    final dto = await descuento();
    return dto > 0 ? medio * (1 - dto / 100.0) : medio;
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
