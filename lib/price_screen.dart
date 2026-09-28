// Pantalla de configuracion del precio de la energia.
//
// El texto explicativo es deliberadamente largo: mucha gente no sabe cual es su
// precio real por kWh y da por bueno el que anuncia la comercializadora, que
// suele ser solo el termino de energia sin impuestos. El metodo de la factura
// (total dividido entre kWh) da una cifra que si refleja lo que se paga.

import 'package:flutter/material.dart';

import 'energy_cost.dart';
import 'pvpc.dart';

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _guardado = false;
  bool _pvpc = false;
  bool _bandas = false;
  final _p1Ctrl = TextEditingController();
  final _p2Ctrl = TextEditingController();
  final _p3Ctrl = TextEditingController();
  final _dtoCtrl = TextEditingController();
  final _ventIniCtrl = TextEditingController();
  final _ventFinCtrl = TextEditingController();
  final _litrosCtrl = TextEditingController();
  final _combCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final vent = await Pvpc.ventana();
    if (vent.contains('-') && mounted) {
      final p2 = vent.split('-');
      _ventIniCtrl.text = p2[0];
      _ventFinCtrl.text = p2[1];
    }
    final term = await Pvpc.termico();
    if (mounted) {
      if (term.litros > 0) {
        _litrosCtrl.text = term.litros.toString().replaceAll('.', ',');
      }
      if (term.precio > 0) {
        _combCtrl.text = term.precio.toString().replaceAll('.', ',');
      }
    }
    final dto = await Pvpc.descuento();
    if (dto > 0 && mounted) {
      _dtoCtrl.text = dto.toString().replaceAll('.', ',');
    }
    final p = await EnergyPrice.load();
    if (p != null && mounted) {
      _ctrl.text = p.eurKwh.toStringAsFixed(4).replaceAll('.', ',');
      _pvpc = p.esPvpc;
      _bandas = p.esBandas;
      if (p.esBandas) {
        _p1Ctrl.text = p.p1!.toStringAsFixed(4).replaceAll('.', ',');
        _p2Ctrl.text = p.p2!.toStringAsFixed(4).replaceAll('.', ',');
        _p3Ctrl.text = p.p3!.toStringAsFixed(4).replaceAll('.', ',');
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _p1Ctrl.dispose();
    _p2Ctrl.dispose();
    _p3Ctrl.dispose();
    _dtoCtrl.dispose();
    _ventIniCtrl.dispose();
    _ventFinCtrl.dispose();
    _litrosCtrl.dispose();
    _combCtrl.dispose();
    super.dispose();
  }

  double? _num(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _guardar() async {
    if (_bandas) {
      final v1 = _num(_p1Ctrl.text);
      final v2 = _num(_p2Ctrl.text);
      final v3 = _num(_p3Ctrl.text);
      if (v1 == null || v2 == null || v3 == null || v1 <= 0 || v2 <= 0 || v3 <= 0) {
        setState(() => _error =
            'Escribe los tres precios, por ejemplo 0,20 / 0,15 / 0,08');
        return;
      }
      if (v1 > 2 || v2 > 2 || v3 > 2) {
        setState(() => _error =
            'Algun precio no parece real. Suele estar entre 0,05 y 0,60');
        return;
      }
      await EnergyPrice.saveBands(v1, v2, v3);
    } else {
      // Coma decimal: en Espana se escribe 0,15 y no 0.15.
      final txt = _ctrl.text.trim().replaceAll(',', '.');
      final v = double.tryParse(txt);
      if (v == null) {
        setState(() => _error = 'Escribe un numero, por ejemplo 0,15');
        return;
      }
      if (v <= 0 || v > 2) {
        setState(() => _error =
            'Ese precio no parece real. Suele estar entre 0,05 y 0,60');
        return;
      }
      await EnergyPrice.save(v, pvpc: _pvpc);
    }
    // El descuento del bono social es del 42,5% y se aplica sobre el total, asi
    // que sin el las cifras salen casi al doble. La API de Red Electrica no
    // sabe nada de ayudas personales, hay que restarlo aparte.
    final dto = double.tryParse(_dtoCtrl.text.replaceAll(',', '.')) ?? 0;
    await Pvpc.setDescuento(dto.clamp(0, 90));
    final vi = _ventIniCtrl.text.trim();
    final vf = _ventFinCtrl.text.trim();
    await Pvpc.setVentana(
        (vi.contains(':') && vf.contains(':')) ? vi + '-' + vf : '');
    await Pvpc.setTermico(
        double.tryParse(_litrosCtrl.text.replaceAll(',', '.')) ?? 0,
        double.tryParse(_combCtrl.text.replaceAll(',', '.')) ?? 0);
    if (!mounted) return;
    setState(() {
      _error = null;
      _guardado = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio guardado')));
  }

  Widget _bloque(String titulo, String cuerpo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(cuerpo,
              style: const TextStyle(fontSize: 13, height: 1.35)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'Precio de la luz' : 'Electricity price')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_bandas)
          TextField(
            controller: _ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: es
                  ? 'Precio por kWh (euros)'
                  : 'Price per kWh (euros)',
              hintText: '0,1543',
              errorText: _error,
              border: const OutlineInputBorder(),
              suffixText: '\u20AC/kWh',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _guardar,
                  child: Text(es ? 'Guardar' : 'Save'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () async {
                  await EnergyPrice.clear();
                  _ctrl.clear();
                  if (!mounted) return;
                  setState(() => _guardado = false);
                },
                child: Text(es ? 'Borrar' : 'Clear'),
              ),
            ],
          ),
          if (_guardado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                es
                    ? 'Guardado. Vuelve al inicio para ver el coste.'
                    : 'Saved. Go back to the dashboard to see the cost.',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ),
          const Divider(height: 32),
          if (!_bandas)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pvpc,
            onChanged: (v) => setState(() {
              _pvpc = v;
              _guardado = false;
            }),
            title: Text(es
                ? 'Tarifa regulada PVPC'
                : 'Regulated PVPC tariff'),
            subtitle: Text(
              es
                  ? 'Precio distinto cada hora, publicado por Red Electrica'
                  : 'A different price each hour, published by the grid operator',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _bandas,
            onChanged: (v) => setState(() {
              _bandas = v;
              if (v) _pvpc = false;
              _guardado = false;
            }),
            title: Text(es
                ? 'Tarifa con 3 tramos (2.0TD)'
                : 'Three-band tariff (2.0TD)'),
            subtitle: Text(
              es
                  ? 'Punta, llano y valle con horarios fijos'
                  : 'Peak, shoulder and off-peak with fixed schedules',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (_bandas) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _p1Ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: es ? 'Punta (P1)' : 'Peak (P1)',
                helperText: es
                    ? 'Laborables de 10:00 a 14:00 y de 18:00 a 22:00'
                    : 'Weekdays 10:00-14:00 and 18:00-22:00',
                hintText: '0,20',
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixText: '\u20AC/kWh',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _p2Ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: es ? 'Llano (P2)' : 'Shoulder (P2)',
                helperText: es
                    ? 'Laborables de 8:00 a 10:00, de 14:00 a 18:00 y de 22:00 a 24:00'
                    : 'Weekdays 8:00-10:00, 14:00-18:00 and 22:00-24:00',
                hintText: '0,15',
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixText: '\u20AC/kWh',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _p3Ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: es ? 'Valle (P3)' : 'Off-peak (P3)',
                helperText: es
                    ? 'Laborables de 0:00 a 8:00 y todo el fin de semana'
                    : 'Weekdays 0:00-8:00 and all weekend',
                hintText: '0,08',
                errorText: _error,
                border: const OutlineInputBorder(),
                suffixText: '\u20AC/kWh',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                es
                    ? 'Cada carga se cobra al precio medio del tramo o tramos por los que paso, segun la hora en que ocurrio.\n\n'
                        'Es la misma aproximacion que con el PVPC: el coche no informa de cuantos kWh entraron en cada hora, '
                        'asi que la energia se reparte por igual entre el inicio y el final de la carga.\n\n'
                        'Sabados y domingos cuentan como valle todo el dia. Los festivos nacionales se tratan como '
                        'laborable: no se arrastra un calendario.\n\n'
                        'Las pantallas que no conocen la hora (ticket, informe, widget) usan la media semanal de tus '
                        'tres precios: 5 laborables con 8 h de cada tramo y el fin de semana entero en valle.'
                    : 'Each charge is priced at the average of the bands it spans, based on when it happened.\n\n'
                        'Same approximation as PVPC: the car does not report per-hour kWh, so energy is spread '
                        'evenly between start and end.\n\n'
                        'Saturday and Sunday count as off-peak all day. National holidays are treated as weekdays.\n\n'
                        'Screens without time data (receipt, report, widget) use the weekly average of your three prices.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_pvpc) ...[
            Text(es ? 'Cuando cargas habitualmente' : 'When you usually charge',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              es
                  ? 'La app no puede saber a que hora cargaste: el coche deja de '
                      'responder al poco de aparcarlo, asi que solo ve el antes y el '
                      'despues. Si nos dices tu franja, el precio se calcula con las '
                      'horas correctas.'
                  : 'The app cannot know when you charged: the car stops responding '
                      'shortly after parking, so it only sees before and after.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ventIniCtrl,
                    decoration: InputDecoration(
                      labelText: es ? 'Desde' : 'From',
                      hintText: '00:00',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _ventFinCtrl,
                    decoration: InputDecoration(
                      labelText: es ? 'Hasta' : 'To',
                      hintText: '08:00',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dtoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: es
                    ? 'Descuento sobre la factura (%)'
                    : 'Discount on the bill (%)',
                hintText: '42,5',
                helperText: es
                    ? 'Bono social u otra ayuda. Dejalo vacio si no tienes ninguna'
                    : 'Social discount or similar. Leave empty if none',
                border: const OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_pvpc)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                es
                    ? 'Cada carga se cobrara al precio medio de las horas en que ocurrio, '
                        'segun los datos que publica Red Electrica.\n\n'
                        'Es una aproximacion: el coche no informa de cuantos kilovatios '
                        'entraron en cada hora, asi que la energia se reparte por igual '
                        'entre el inicio y el final de la carga. En una carga lenta '
                        'nocturna se acerca bastante.\n\n'
                        'De momento solo hay datos de la peninsula. Si no se pueden '
                        'consultar los precios de algun dia, se usara el precio fijo de '
                        'arriba, que conviene dejar puesto como respaldo.\n\n'
                        'El descuento se resta del precio publicado por Red Electrica. Si '
                        'la cifra que tu ves en tu comercializadora ya viene descontada, '
                        'deja el campo vacio para no restarlo dos veces.'
                    : 'Each charge is priced at the average of the hours it took place, '
                        'using the grid operator data.\n\nIt is an approximation: the car '
                        'does not report how many kWh entered each hour, so energy is '
                        'spread evenly between start and end.\n\nMainland Spain only. If '
                        'prices cannot be fetched, the fixed price above is used as '
                        'fallback, so keep it set.',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          _bloque(
            es ? 'Como saber tu precio real' : 'Finding your real price',
            es
                ? 'Coge una factura reciente y divide el TOTAL a pagar entre los kWh consumidos que aparecen en ella. Ese numero incluye ya el IVA, el impuesto electrico y el termino de potencia repartido, asi que refleja lo que de verdad te cuesta cada kilovatio.\n\nEjemplo: 84,60 EUR de total entre 548 kWh son 0,1544 EUR/kWh.\n\nSi prefieres usar solo el precio de tu tarifa, asegurate de coger el que lleva impuestos incluidos. El que anuncian las comercializadoras suele ir sin ellos y se queda corto en torno a un 25%.'
                : 'Take a recent bill and divide the TOTAL amount by the kWh shown on it. That figure already includes taxes and the fixed power term, so it reflects what each kilowatt-hour truly costs you.\n\nExample: 84.60 EUR total over 548 kWh gives 0.1544 EUR/kWh.\n\nIf you prefer your tariff rate, make sure it is the one including taxes. Advertised rates usually exclude them and fall short by around 25%.',
          ),
          _bloque(
            es ? 'Por que la cifra sale corta' : 'Why the figure runs low',
            es
                ? 'La app mide la energia que hay en la bateria del coche, no la que pasa por tu contador. Cargar no es gratis en energia: entre el enchufe y la bateria se pierde alrededor de un 12% en forma de calor.\n\nEso significa que el coste que ves aqui es algo menor que el de tu factura. Es intencionado: mide lo que el coche realmente usa para moverse. Si quieres una estimacion de lo que pagas, sumale un 12% a ojo.'
                : 'The app measures the energy in the car battery, not what goes through your meter. Charging is not free: around 12% is lost as heat between the socket and the battery.\n\nSo the cost shown here is somewhat lower than your bill. That is deliberate: it measures what the car actually uses to move. For a rough idea of what you pay, add about 12%.',
          ),
          const Divider(height: 32),
          Text(es ? 'Comparar con un termico' : 'Compare with a petrol car',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            es
                ? 'Si vienes de un diesel o gasolina, indica lo que gastaba y lo que '
                    'cuesta el combustible. El informe calculara el ahorro con tus '
                    'cifras en vez de con una referencia generica.'
                : 'Coming from a petrol or diesel car? Enter its consumption and fuel '
                    'price and the report will use your own figures.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _litrosCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: es ? 'Consumo' : 'Consumption',
                    hintText: '6,5',
                    suffixText: 'l/100',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _combCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: es ? 'Precio' : 'Price',
                    hintText: '1,55',
                    suffixText: '\u20AC/l',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            es
                ? 'Se guarda al pulsar Guardar, arriba.'
                : 'Saved with the Save button above.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _bloque(
            es ? 'Un precio o tres' : 'One price or three',
            es
                ? 'Con un precio unico, todo se cobra a ese precio. Con los 3 tramos, cada carga se cobra segun la hora en que ocurrio: si cargas de madrugada, pagaras lo que de verdad cuesta.\n\n'
                    'Las cargas en cargadores publicos se distinguen anotando su coste a mano: toca una carga en el historial y rellena lo que pagaste. Eso ademas permite calcular tus perdidas reales de carga.'
                : 'With a flat price, everything is charged at that price. With the three bands, each charge is priced by when it happened: charge overnight and you pay what it truly costs.\n\n'
                    'Public charging is told apart by entering its cost by hand: tap a charge in the history and fill in what you paid. That also enables real charging-loss tracking.',
          ),
          _bloque(
            es ? 'Donde se guarda' : 'Where it is stored',
            es
                ? 'El precio se guarda cifrado dentro del telefono y no sale de el. No se envia a ningun servidor ni forma parte de las copias de seguridad.'
                : 'The price is stored encrypted on your phone and never leaves it. It is not sent to any server and is not part of backups.',
          ),
        ],
      ),
    );
  }
}
