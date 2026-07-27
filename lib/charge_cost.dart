// Coste real de cada carga.
//
// Por que hace falta: el coste estimado multiplica los kWh por el precio de
// casa, y eso deja de valer en cuanto cargas de viaje. Un cargador rapido
// puede costar cuatro veces mas. Aqui se guarda, por carga, lo que costo de
// verdad.
//
// Todo es opcional. Si una carga no tiene datos, se sigue estimando con el
// precio de casa y se marca como estimacion en pantalla.
//
// Regalo: si se meten el total pagado Y los kWh que marco el cargador, se
// puede calcular la eficiencia de carga REAL (kWh que entraron en bateria
// entre kWh que cobro el cargador) en vez del 12% teorico.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _ccStorage = FlutterSecureStorage();
const kChargeCostsKey = 'lm_charge_costs_v1';

class ChargeCost {
  final int ts; // startTs de la carga, hace de clave
  final double? eur; // total pagado
  final double? eurKwh; // precio por kWh del punto
  final double? kwhCargador; // kWh que marco el cargador
  final String tipo; // 'casa' | 'publica'

  const ChargeCost({
    required this.ts,
    this.eur,
    this.eurKwh,
    this.kwhCargador,
    this.tipo = 'casa',
  });

  bool get vacio => eur == null && eurKwh == null && kwhCargador == null;

  Map<String, dynamic> toMap() => {
        'ts': ts,
        'eur': eur,
        'eurKwh': eurKwh,
        'kwhCargador': kwhCargador,
        'tipo': tipo,
      };

  static ChargeCost? fromMap(Map<String, dynamic> m) {
    final ts = m['ts'];
    if (ts is! int) return null;
    double? d(dynamic v) => v is num ? v.toDouble() : null;
    return ChargeCost(
      ts: ts,
      eur: d(m['eur']),
      eurKwh: d(m['eurKwh']),
      kwhCargador: d(m['kwhCargador']),
      tipo: (m['tipo'] as String?) ?? 'casa',
    );
  }
}

class ChargeCostStore {
  static Future<Map<int, ChargeCost>> loadAll() async {
    try {
      final raw = await _ccStorage.read(key: kChargeCostsKey);
      if (raw == null || raw.isEmpty) return {};
      final out = <int, ChargeCost>{};
      for (final e in (json.decode(raw) as List)) {
        final c = ChargeCost.fromMap(Map<String, dynamic>.from(e as Map));
        if (c != null) out[c.ts] = c;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  static Future<void> put(ChargeCost c) async {
    final all = await loadAll();
    if (c.vacio) {
      all.remove(c.ts);
    } else {
      all[c.ts] = c;
    }
    await _ccStorage.write(
        key: kChargeCostsKey,
        value: json.encode(all.values.map((e) => e.toMap()).toList()));
  }
}

/// Resuelve lo que costo una carga, por orden de fiabilidad:
///   1. total pagado          -> exacto
///   2. precio por kWh        -> exacto (sobre los kWh del cargador si los hay)
///   3. precio de casa        -> ESTIMADO
double? costeCarga({
  required double kwhBateria,
  ChargeCost? manual,
  double? precioCasa,
  required void Function(bool estimado) marca,
}) {
  if (manual != null) {
    if (manual.eur != null) {
      marca(false);
      return manual.eur;
    }
    if (manual.eurKwh != null) {
      marca(false);
      return manual.eurKwh! * (manual.kwhCargador ?? kwhBateria);
    }
  }
  if (precioCasa != null) {
    marca(true);
    return precioCasa * kwhBateria;
  }
  return null;
}

/// Eficiencia de carga observada, o null si no hay datos suficientes.
/// Solo cuentan las cargas donde se anoto lo que marco el cargador.
double? eficienciaObservada(
    Map<int, ChargeCost> costes, Map<int, double> kwhBateriaPorTs) {
  var bat = 0.0, red = 0.0;
  costes.forEach((ts, c) {
    final k = c.kwhCargador;
    final b = kwhBateriaPorTs[ts];
    if (k != null && k > 0 && b != null && b > 0) {
      bat += b;
      red += k;
    }
  });
  if (red <= 0) return null;
  final e = bat / red;
  return (e > 0.5 && e < 1.0) ? e : null;
}

/// Dialogo de edicion. Devuelve true si se guardo algo.
Future<bool> editarCosteCarga(
    BuildContext context, int ts, double kwhBateria, ChargeCost? actual) async {
  final ctrlEur = TextEditingController(
      text: actual?.eur == null ? '' : _txt(actual!.eur!));
  final ctrlEurKwh = TextEditingController(
      text: actual?.eurKwh == null ? '' : _txt(actual!.eurKwh!));
  final ctrlKwh = TextEditingController(
      text: actual?.kwhCargador == null ? '' : _txt(actual!.kwhCargador!));
  var tipo = actual?.tipo ?? 'casa';

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: const Text('Coste de esta carga'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entraron ' +
                    kwhBateria.toStringAsFixed(1) +
                    ' kWh en la bateria. Rellena solo lo que sepas.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Casa'),
                    selected: tipo == 'casa',
                    onSelected: (_) => setSt(() => tipo = 'casa'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Publica'),
                    selected: tipo == 'publica',
                    onSelected: (_) => setSt(() => tipo = 'publica'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlEur,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total pagado',
                  helperText: 'Lo que pone el ticket. Es lo mas fiable.',
                  suffixText: '\u20AC',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlEurKwh,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Precio del punto',
                  helperText: 'Solo si no sabes el total.',
                  suffixText: '\u20AC/kWh',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrlKwh,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'kWh que marco el cargador',
                  helperText:
                      'Opcional. Con esto la app aprende tus perdidas reales.',
                  suffixText: 'kWh',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    ),
  );

  if (ok != true) return false;
  await ChargeCostStore.put(ChargeCost(
    ts: ts,
    eur: _num(ctrlEur.text),
    eurKwh: _num(ctrlEurKwh.text),
    kwhCargador: _num(ctrlKwh.text),
    tipo: tipo,
  ));
  return true;
}

String _txt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

double? _num(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return (v == null || v <= 0) ? null : v;
}
