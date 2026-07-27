// Pantalla de configuracion del precio de la energia.
//
// El texto explicativo es deliberadamente largo: mucha gente no sabe cual es su
// precio real por kWh y da por bueno el que anuncia la comercializadora, que
// suele ser solo el termino de energia sin impuestos. El metodo de la factura
// (total dividido entre kWh) da una cifra que si refleja lo que se paga.

import 'package:flutter/material.dart';

import 'energy_cost.dart';

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await EnergyPrice.load();
    if (p != null && mounted) {
      _ctrl.text = p.eurKwh.toStringAsFixed(4).replaceAll('.', ',');
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // Coma decimal: en Espana se escribe 0,15 y no 0.15.
    final txt = _ctrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(txt);
    if (v == null) {
      setState(() => _error = 'Escribe un numero, por ejemplo 0,15');
      return;
    }
    if (v <= 0 || v > 2) {
      setState(() =>
          _error = 'Ese precio no parece real. Suele estar entre 0,05 y 0,60');
      return;
    }
    await EnergyPrice.save(v);
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
          _bloque(
            es ? 'Un solo precio, de momento' : 'A single price, for now',
            es
                ? 'Ahora mismo se aplica el mismo precio a todo. Si tienes tarifa con tramos horarios (valle, llano y punta) y cargas de madrugada, estaras pagando menos de lo que aqui se calcula: pon el precio del tramo en el que sueles cargar.\n\nLas cargas en cargadores publicos tampoco se distinguen, y suelen costar bastante mas.\n\nAmbas cosas estan previstas para mas adelante.'
                : 'The same price applies to everything for now. If your tariff has time bands and you charge at night, you are paying less than shown here: enter the price of the band where you usually charge.\n\nPublic charging is not told apart either, and it is usually much more expensive.\n\nBoth are planned for later.',
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
