#!/bin/bash
# ============================================================================
# LMB10 - pack_joyas.sh  —  Potencia real (kW) + alerta visual de presion
#
#  1) batteryPowerKw: getter que lee batteryCurrent x batteryVoltage / 1000
#     del raw (unidades confirmadas: 19,8 A x 422,1 V = 8,36 kW). Se muestra en
#     una tarjeta del dashboard con color: azul=regenerando (negativo),
#     verde=eficiente (bajo), naranja=alto consumo. Valor instantaneo del
#     refresco (cada 90s), util como "voy eficiente ahora?".
#  2) Alerta de presion: usa el getter tirePressureAlerts (ya existente) para
#     mostrar una franja de aviso en la tarjeta de neumaticos si alguna rueda
#     marca presion anomala. Presion baja = mas consumo = menos autonomia.
#
# Ejecutar desde la raiz: bash pack_joyas.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz del proyecto"; exit 1; }
mkdir -p backups_widget
cp lib/leapmotor_engine.dart backups_widget/leapmotor_engine.dart.bak_joyas
cp lib/main.dart backups_widget/main.dart.bak_joyas

# ---------------------------------------------------------------------------
# 1) Engine: getter batteryPowerKw
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/leapmotor_engine.dart'
s = open(p, encoding='utf-8').read()
anchor = "  bool get isPluggedIn => (acInputSlowCharge ?? false) || (dcInputFastCharge ?? false);"
add = """  /// Potencia instantanea de la bateria en kW (corriente x voltaje / 1000).
  /// Positivo = saliendo (consumo/carga), negativo = entrando por regeneracion.
  /// Unidades del coche confirmadas en A y V (p. ej. 19,8 A x 422,1 V = 8,4 kW).
  double? get batteryPowerKw {
    final c = raw['batteryCurrent'];
    final v = raw['batteryVoltage'];
    final cn = c is num ? c.toDouble() : (c is String ? double.tryParse(c) : null);
    final vn = v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    if (cn == null || vn == null) return null;
    return cn * vn / 1000.0;
  }

  bool get isPluggedIn => (acInputSlowCharge ?? false) || (dcInputFastCharge ?? false);"""
if s.count(anchor)!=1:
    print(f"ERROR engine: ancla x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, add)
open(p,'w',encoding='utf-8').write(s)
print("OK  engine: getter batteryPowerKw")
PYEOF

# ---------------------------------------------------------------------------
# 2) Dashboard: tarjeta de potencia + alerta de presion
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()

# 2a) Insertar la tarjeta de potencia en el dashboard, justo antes de TirePressureCard
anchor = "                      TirePressureCard(status: s),"
card = """                      PowerCard(status: s),
                      const SizedBox(height: 12),
                      TirePressureCard(status: s),"""
if s.count(anchor)!=1:
    print(f"ERROR dashboard: ancla TirePressureCard x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, card)
print("OK  dashboard: PowerCard insertada")

# 2b) Añadir aviso de presion dentro de TirePressureCard (tras los dos Rows)
anchor2 = """          const SizedBox(height: 8),
          Row(children: [
            tile(AppLocalizations.of(context)!.tireRearLeft, status.leftRearTireKpa),
            tile(AppLocalizations.of(context)!.tireRearRight, status.rightRearTireKpa),
          ]),
        ],
      ),
    );
  }
}"""
new2 = """          const SizedBox(height: 8),
          Row(children: [
            tile(AppLocalizations.of(context)!.tireRearLeft, status.leftRearTireKpa),
            tile(AppLocalizations.of(context)!.tireRearRight, status.rightRearTireKpa),
          ]),
          if (status.tirePressureAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE76F51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (Localizations.localeOf(context).languageCode == 'es'
                              ? 'Revisa la presion: '
                              : 'Check pressure: ') +
                          status.tirePressureAlerts.join(', '),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}"""
if s.count(anchor2)!=1:
    print(f"ERROR presion: ancla x{s.count(anchor2)}"); sys.exit(1)
s = s.replace(anchor2, new2)
print("OK  TirePressureCard: aviso de presion")

# 2c) Definir el widget PowerCard (lo añadimos justo antes de class TirePressureCard)
anchor3 = "class TirePressureCard extends StatelessWidget {"
powercard = """class PowerCard extends StatelessWidget {
  final VehicleStatus status;
  const PowerCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final kw = status.batteryPowerKw;
    const textColor = Color(0xFF0D3B66);
    if (kw == null) return const SizedBox.shrink();

    // Color e interpretacion segun el flujo de potencia.
    Color c;
    String note;
    if (kw < -1) {
      c = const Color(0xFF2A6FD0); // azul: regenerando
      note = es ? 'Regenerando (recuperas bateria)' : 'Regenerating (recovering)';
    } else if (kw <= 10) {
      c = const Color(0xFF2A9D8F); // verde: eficiente
      note = es ? 'Consumo eficiente' : 'Efficient draw';
    } else if (kw <= 30) {
      c = const Color(0xFFE9A23B); // ambar
      note = es ? 'Consumo medio' : 'Medium draw';
    } else {
      c = const Color(0xFFE76F51); // rojo: alto
      note = es ? 'Consumo alto' : 'High draw';
    }
    final sign = kw < 0 ? '' : '';
    final valueStr = '${sign}${kw.abs().toStringAsFixed(1)} kW';

    return Container(
      decoration: BoxDecoration(color: const Color(0xFFBFE0FA), borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(es ? 'Potencia de bateria (ahora)' : 'Battery power (now)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(kw < -1 ? Icons.battery_charging_full : Icons.bolt, color: c, size: 30),
              const SizedBox(width: 8),
              Text(valueStr, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 26)),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            es ? 'Valor puntual del ultimo refresco.' : 'Snapshot from last refresh.',
            style: const TextStyle(color: textColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class TirePressureCard extends StatelessWidget {"""
if s.count(anchor3)!=1:
    print(f"ERROR PowerCard def: ancla x{s.count(anchor3)}"); sys.exit(1)
s = s.replace(anchor3, powercard)
print("OK  PowerCard definida")

open(p,'w',encoding='utf-8').write(s)
PYEOF

echo "LISTO. Compila: flutter build apk --release"
