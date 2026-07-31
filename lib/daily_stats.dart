// Agregado diario de consumo.
//
// Motivo: trips.jsonl crece ~250 lineas al dia y se estaba parseando ENTERO
// cada 90 s. A un ano vista son ~90.000 lineas y deja de ser viable. Aqui se
// precalcula una linea por dia y las vistas de semanas y meses se suman desde
// ahi, no desde los puntos crudos.
//
// La matematica es la MISMA que averageConsumptionPercentPer100km: esa funcion
// acumula totalKm y totalSocDrop de los tramos aceptados y divide al final, asi
// que guardar los sumatorios por dia y sumarlos da un resultado identico.
// Validado contra el historico real del 26/07/2026: diferencia 0.000 %/100km
// en la ventana de 7 dias.
//
// Los umbrales (km minimos, media creible) se aplican AL PINTAR, no al guardar.
// Si se aplicaran al guardar, un dia de 3 km se descartaria y sus km no
// contarian para la semana, cuando son perfectamente validos dentro del total.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'widget_chart.dart' show gBatteryKwh;

class DayAgg {
  final String d; // 'yyyy-MM-dd', o '2026-S30' / '2026-07' si es un rollup
  double km;
  double soc;
  int segs;
  int pts;

  /// Kilometros recorridos de verdad, sin filtrar por consumo. Ver kmAll.
  double kmAllRaw;

  DayAgg(this.d,
      {this.km = 0,
      this.soc = 0,
      this.segs = 0,
      this.pts = 0,
      this.kmAllRaw = 0});

  /// Distancia recorrida del dia.
  ///
  /// `km` solo acumula los tramos que pasan los filtros de consumo, porque esa
  /// cifra alimenta la media y no puede contaminarse. Pero para MOSTRAR
  /// kilometros eso deja fuera trayectos reales: un tramo que mezcle conducir y
  /// cargar tiene socDelta <= 0 y se descarta entero.
  ///
  /// El respaldo a `km` es deliberado: los agregados antiguos y los rollups que
  /// todavia no sumen kmAllRaw devuelven lo de siempre en vez de cero.
  double get kmAll => kmAllRaw > 0 ? kmAllRaw : km;

  /// Consumo en % de bateria por 100 km, o null si no es creible.
  double? get pct {
    if (km < DailyStats.kMinKm) return null;
    final a = soc / km * 100.0;
    if (a < DailyStats.kMinAvg || a > DailyStats.kMaxAvg) return null;
    return a;
  }

  double? get kwh100 {
    final p = pct;
    return p == null ? null : p / 100.0 * gBatteryKwh;
  }

  Map<String, dynamic> toMap() => {
        'd': d,
        'km': km,
        'soc': soc,
        'segs': segs,
        'pts': pts,
        'kmAll': kmAllRaw,
      };

  static DayAgg? fromMap(Map<String, dynamic> m) {
    final d = m['d'];
    if (d is! String) return null;
    return DayAgg(d,
        km: (m['km'] as num?)?.toDouble() ?? 0,
        soc: (m['soc'] as num?)?.toDouble() ?? 0,
        segs: (m['segs'] as num?)?.toInt() ?? 0,
        pts: (m['pts'] as num?)?.toInt() ?? 0,
        kmAllRaw: (m['kmAll'] as num?)?.toDouble() ?? 0);
  }
}

class DailyStats {
  // Mismos umbrales que averageConsumptionPercentPer100km. Una sola verdad.
  static const double kSegMin = 8.0; // %/100km imposible por debajo
  static const double kSegMax = 70.0; // %/100km imposible por encima
  static const double kMinKm = 5.0; // km minimos para dar dato
  static const double kMinAvg = 12.0; // media final creible
  static const double kMaxAvg = 70.0;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(base.path + '/lmb10_history');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> _trips() async => tripsFile();

  /// Publico para que ChargeRebuild no duplique la ruta del historico.
  static Future<File> tripsFile() async =>
      File((await _dir()).path + '/trips.jsonl');
  static Future<File> _agg() async =>
      File((await _dir()).path + '/daily_agg.jsonl');
  static Future<File> _meta() async =>
      File((await _dir()).path + '/daily_agg_meta.json');

  static String dayKey(DateTime t) =>
      t.year.toString().padLeft(4, '0') +
      '-' +
      t.month.toString().padLeft(2, '0') +
      '-' +
      t.day.toString().padLeft(2, '0');

  /// Semana ISO: la que contiene el jueves.
  static String weekKey(DateTime t) {
    final thu = DateTime(t.year, t.month, t.day)
        .add(Duration(days: 4 - t.weekday));
    final jan1 = DateTime(thu.year, 1, 1);
    final w = (thu.difference(jan1).inDays / 7).floor() + 1;
    return thu.year.toString() + '-S' + w.toString().padLeft(2, '0');
  }

  static String monthKey(DateTime t) =>
      t.year.toString().padLeft(4, '0') +
      '-' +
      t.month.toString().padLeft(2, '0');

  /// Reconstruye el agregado entero desde trips.jsonl. Deduplica en memoria;
  /// NUNCA reescribe trips.jsonl (es la unica fuente de verdad).
  static Future<List<DayAgg>> rebuild() async {
    final f = await _trips();
    if (!await f.exists()) return <DayAgg>[];

    final seen = <String>{};
    final pts = <List<num>>[];
    final raw = await f.readAsString();
    for (final line in const LineSplitter().convert(raw)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(json.decode(t) as Map);
        final ts = m['ts'];
        final km = m['km'];
        final soc = m['soc'];
        if (ts is! int || km is! int || soc is! num) continue;
        final k = ts.toString() + ':' + km.toString() + ':' + soc.toString();
        if (!seen.add(k)) continue; // duplicado exacto
        pts.add([ts, km, soc.toDouble()]);
      } catch (_) {}
    }
    pts.sort((a, b) => (a[0] as int).compareTo(b[0] as int));

    final days = _accumulate(pts);
    await _write(days);
    await _saveMeta(raw.length, pts.isEmpty ? null : pts.last);
    return days.values.toList();
  }

  /// Un tramo cuenta para un dia solo si SUS DOS EXTREMOS caen en ese dia.
  /// Es exactamente lo que hace el calculo por dia actual, y esta medido que
  /// los tramos que cruzan medianoche aportan cero (o cargas o coche parado).
  static Map<String, DayAgg> _accumulate(List<List<num>> pts) {
    final days = <String, DayAgg>{};
    for (var i = 0; i < pts.length; i++) {
      final cur = pts[i];
      final kCur =
          dayKey(DateTime.fromMillisecondsSinceEpoch(cur[0] as int));
      final agg = days.putIfAbsent(kCur, () => DayAgg(kCur));
      agg.pts += 1;
      if (i == 0) continue;
      final prev = pts[i - 1];
      final kPrev =
          dayKey(DateTime.fromMillisecondsSinceEpoch(prev[0] as int));
      if (kPrev != kCur) continue;
      final kmDelta = (cur[1] - prev[1]).toDouble();
      final socDelta = (prev[2] - cur[2]).toDouble();
      if (kmDelta <= 0) continue;

      // Los kilometros se acumulan AQUI, antes de los filtros de consumo.
      // Antes se sumaban despues, asi que un tramo con socDelta <= 0 perdia sus
      // kilometros enteros. Con la app abierta apenas se nota (se muestrea cada
      // 90 s), pero con la app dormida un tramo puede abarcar un viaje de 30 km
      // y la recarga posterior, y esos 30 km desaparecian del total.
      agg.kmAllRaw += kmDelta;

      if (socDelta <= 0) continue;
      final pct = socDelta / kmDelta * 100.0;
      if (pct < kSegMin || pct > kSegMax) continue;
      agg.km += kmDelta;
      agg.soc += socDelta;
      agg.segs += 1;
    }
    return days;
  }

  static Future<void> _write(Map<String, DayAgg> days) async {
    final keys = days.keys.toList()..sort();
    final sb = StringBuffer();
    for (final k in keys) {
      sb.writeln(json.encode(days[k]!.toMap()));
    }
    await (await _agg()).writeAsString(sb.toString(), flush: true);
  }

  static Future<void> _saveMeta(int len, List<num>? last) async {
    // v2: los kilometros dejan de filtrarse por consumo. Al subir de version
    // se fuerza un rebuild para que el historico tambien salga corregido.
    final m = <String, dynamic>{'len': len, 'v': 2};
    if (last != null) {
      m['lastTs'] = last[0];
      m['lastKm'] = last[1];
      m['lastSoc'] = last[2];
    }
    await (await _meta()).writeAsString(json.encode(m), flush: true);
  }

  /// Pone el agregado al dia leyendo SOLO los bytes nuevos de trips.jsonl.
  /// Si el fichero encogio (restauracion de backup, migracion) reconstruye
  /// entero, porque el offset guardado ya no significa nada.
  static Future<List<DayAgg>> sync() async {
    final f = await _trips();
    if (!await f.exists()) return <DayAgg>[];
    final mf = await _meta();
    if (!await mf.exists()) return rebuild();

    Map<String, dynamic> meta;
    try {
      meta = Map<String, dynamic>.from(json.decode(await mf.readAsString()));
    } catch (_) {
      return rebuild();
    }
    if (((meta['v'] as num?)?.toInt() ?? 1) < 2) return rebuild();
    final prevLen = (meta['len'] as num?)?.toInt() ?? 0;
    final len = await f.length();
    if (len < prevLen) return rebuild();
    if (len == prevLen) return load();

    final raf = await f.open();
    await raf.setPosition(prevLen);
    final bytes = await raf.read(len - prevLen);
    await raf.close();
    var chunk = utf8.decode(bytes, allowMalformed: true);

    // Si el ultimo renglon esta a medias (escritura en curso), se descarta y
    // se guarda el offset justo antes: entrara completo en la proxima pasada.
    var consumed = bytes.length;
    final cut = chunk.lastIndexOf('\n');
    if (cut < 0) return load();
    consumed = utf8.encode(chunk.substring(0, cut + 1)).length;
    chunk = chunk.substring(0, cut + 1);

    final nue = <List<num>>[];
    if (meta['lastTs'] is num) {
      nue.add([
        (meta['lastTs'] as num).toInt(),
        (meta['lastKm'] as num).toInt(),
        (meta['lastSoc'] as num).toDouble()
      ]);
    }
    final seen = <String>{};
    for (final line in const LineSplitter().convert(chunk)) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(json.decode(t) as Map);
        final ts = m['ts'];
        final km = m['km'];
        final soc = m['soc'];
        if (ts is! int || km is! int || soc is! num) continue;
        final k = ts.toString() + ':' + km.toString() + ':' + soc.toString();
        if (!seen.add(k)) continue;
        nue.add([ts, km, soc.toDouble()]);
      } catch (_) {}
    }
    if (nue.length < 2) {
      await _saveMeta(prevLen + consumed, nue.isEmpty ? null : nue.last);
      return load();
    }
    nue.sort((a, b) => (a[0] as int).compareTo(b[0] as int));

    // Se fusiona con lo ya guardado. El primer punto es el arrastrado del
    // tramo anterior, asi que su 'pts' ya estaba contado: se descuenta.
    final days = <String, DayAgg>{};
    for (final a in await load()) {
      days[a.d] = a;
    }
    final delta = _accumulate(nue);
    if (meta['lastTs'] is num) {
      final kFirst = dayKey(DateTime.fromMillisecondsSinceEpoch(
          (meta['lastTs'] as num).toInt()));
      final dd = delta[kFirst];
      if (dd != null) dd.pts -= 1;
    }
    delta.forEach((k, v) {
      final ex = days[k];
      if (ex == null) {
        days[k] = v;
      } else {
        ex.km += v.km;
        ex.soc += v.soc;
        ex.segs += v.segs;
        ex.pts += v.pts;
      }
    });

    await _write(days);
    await _saveMeta(prevLen + consumed, nue.last);
    return days.values.toList()..sort((a, b) => a.d.compareTo(b.d));
  }

  static Future<List<DayAgg>> load() async {
    final f = await _agg();
    if (!await f.exists()) return <DayAgg>[];
    final out = <DayAgg>[];
    try {
      for (final line in await f.readAsLines()) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final a =
            DayAgg.fromMap(Map<String, dynamic>.from(json.decode(t) as Map));
        if (a != null) out.add(a);
      }
    } catch (_) {}
    out.sort((a, b) => a.d.compareTo(b.d));
    return out;
  }

  static List<DayAgg> rollup(List<DayAgg> days, String Function(DateTime) key) {
    final out = <String, DayAgg>{};
    for (final a in days) {
      DateTime t;
      try {
        t = DateTime.parse(a.d);
      } catch (_) {
        continue;
      }
      final k = key(t);
      final b = out.putIfAbsent(k, () => DayAgg(k));
      b.km += a.km;
      b.kmAllRaw += a.kmAll;
      b.soc += a.soc;
      b.segs += a.segs;
      b.pts += a.pts;
    }
    final keys = out.keys.toList()..sort();
    return keys.map((k) => out[k]!).toList();
  }

  static List<DayAgg> weeks(List<DayAgg> days) => rollup(days, weekKey);
  static List<DayAgg> months(List<DayAgg> days) => rollup(days, monthKey);

  /// Linea de diagnostico para el log del coche. Sirve para comprobar contra
  /// el 'CONSUMO avg7=' que ya existe: deben coincidir.
  static Future<String> diagnostic() async {
    final days = await load();
    if (days.isEmpty) return 'sin datos';
    final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
    var km = 0.0;
    var soc = 0.0;
    for (final a in last7) {
      km += a.km;
      soc += a.soc;
    }
    final avg = km > 0 ? (soc / km * 100.0) : 0.0;
    return 'dias=' +
        days.length.toString() +
        ' avg7=' +
        avg.toStringAsFixed(2) +
        ' km7=' +
        km.toStringAsFixed(0) +
        ' sem=' +
        weeks(days).length.toString() +
        ' mes=' +
        months(days).length.toString();
  }
}

/// Reconstruccion del historial de cargas a partir de trips.jsonl.
///
/// Por que hace falta: la deteccion en vivo se dispara con el flanco de
/// isCharging (!wasCharging && isCharging), asi que exige sondear MIENTRAS el
/// coche carga. Eso no ocurre. En el historico real del 26/07/2026 hay 32
/// huecos de mas de una hora, y las dos unicas recargas visibles son un salto
/// de SoC a traves de un hueco sin muestras (20,3 h y 1,8 h). Doze aplasta el
/// WorkManager de madrugada, que es justo cuando se carga, y el TCU se duerme
/// a los ~13 min. Resultado: chargeSessions vacio desde la instalacion.
///
/// Se detecta igual que el ciclo de carga: por subida de SoC entre puntos
/// consecutivos. NO se puede saber la duracion real ni la potencia (entre dos
/// muestras pueden pasar 20 h y la carga durar 4), asi que no se muestran.
class RebuiltCharge {
  final int startTs;
  final int endTs;
  final double startSoc;
  final double endSoc;
  final int samples;

  RebuiltCharge(
      this.startTs, this.endTs, this.startSoc, this.endSoc, this.samples);

  double get gain => endSoc - startSoc;
  double get kwh => gain / 100.0 * gBatteryKwh;

  /// Solo hay duracion fiable si se llego a ver la carga por dentro.
  bool get durationMeasured => samples > 2;
}

class ChargeRebuild {
  static const double kMinGain = 1.0; // % de SoC minimo para contar como carga
  static const int kMergeGapMs = 30 * 60 * 1000;

  // La tarjeta recarga en cada refresco; sin cache se reparsearia el historico
  // entero cada 90 s. La longitud del fichero basta como testigo: solo crece.
  static int _cacheLen = -1;
  static List<RebuiltCharge> _cache = <RebuiltCharge>[];

  static Future<List<RebuiltCharge>> fromTrips() async {
    final f = await DailyStats.tripsFile();
    if (!await f.exists()) return <RebuiltCharge>[];
    final len = await f.length();
    if (len == _cacheLen) return _cache;

    final seen = <String>{};
    final pts = <List<num>>[];
    for (final line in await f.readAsLines()) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(json.decode(t) as Map);
        final ts = m['ts'];
        final soc = m['soc'];
        if (ts is! int || soc is! num) continue;
        final k = ts.toString() + ':' + soc.toString();
        if (!seen.add(k)) continue;
        pts.add([ts, soc.toDouble()]);
      } catch (_) {}
    }
    pts.sort((a, b) => (a[0] as int).compareTo(b[0] as int));

    final runs = <RebuiltCharge>[];
    int? ini;
    for (var i = 1; i < pts.length; i++) {
      final d = pts[i][1].toDouble() - pts[i - 1][1].toDouble();
      if (d > 0) {
        ini ??= i - 1;
      } else if (ini != null) {
        runs.add(RebuiltCharge(
            pts[ini][0].toInt(),
            pts[i - 1][0].toInt(),
            pts[ini][1].toDouble(),
            pts[i - 1][1].toDouble(),
            i - ini));
        ini = null;
      }
    }
    if (ini != null) {
      final last = pts.length - 1;
      runs.add(RebuiltCharge(
          pts[ini][0].toInt(),
          pts[last][0].toInt(),
          pts[ini][1].toDouble(),
          pts[last][1].toDouble(),
          last - ini + 1));
    }

    // Une rachas casi pegadas: una meseta de SoC a mitad de carga (dos lecturas
    // con el mismo decimal) partiria una carga real en dos.
    final merged = <RebuiltCharge>[];
    for (final r in runs) {
      if (merged.isNotEmpty && r.startTs - merged.last.endTs <= kMergeGapMs) {
        final p = merged.removeLast();
        merged.add(RebuiltCharge(
            p.startTs, r.endTs, p.startSoc, r.endSoc, p.samples + r.samples));
      } else {
        merged.add(r);
      }
    }

    final out = merged.where((r) => r.gain >= kMinGain).toList();
    _cacheLen = len;
    _cache = out;
    return out;
  }
}
