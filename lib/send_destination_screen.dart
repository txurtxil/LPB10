// send_destination_screen.dart
//
// Enviar un destino de navegacion al coche (cmdId=180, SIN PIN).
// Busqueda por Nominatim (OpenStreetMap), confirmacion y envio.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as plain_http;
import 'leapmotor_engine.dart';

class _Destino {
  final String nombre, direccion;
  final double lat, lon;
  const _Destino(this.nombre, this.direccion, this.lat, this.lon);
}

class SendDestinationScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  const SendDestinationScreen({super.key, required this.client, required this.vehicle});

  @override
  State<SendDestinationScreen> createState() => _SendDestinationScreenState();
}

class _SendDestinationScreenState extends State<SendDestinationScreen> {
  final _ctrl = TextEditingController();
  bool _buscando = false;
  bool _enviando = false;
  String? _error;
  List<_Destino> _resultados = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _buscando = true;
      _error = null;
      _resultados = [];
    });
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=jsonv2&limit=6&accept-language=es');
      final resp = await plain_http
          .get(uri, headers: {'User-Agent': 'LMB10-app (uso personal)'})
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (resp.statusCode != 200) {
        setState(() {
          _buscando = false;
          _error = 'HTTP ${resp.statusCode}';
        });
        return;
      }
      final lista = json.decode(resp.body) as List;
      setState(() {
        _resultados = [
          for (final r in lista)
            _Destino(
              (r['name']?.toString().isNotEmpty == true)
                  ? r['name'].toString()
                  : r['display_name'].toString().split(',').first,
              r['display_name'].toString(),
              double.tryParse(r['lat'].toString()) ?? 0,
              double.tryParse(r['lon'].toString()) ?? 0,
            ),
        ];
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _confirmarYEnviar(_Destino d) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(es ? 'Enviar al coche' : 'Send to car'),
        content: Text('${d.nombre}\n${d.direccion}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(es ? 'Cancelar' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(es ? 'Enviar' : 'Send'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enviando = true);
    try {
      await widget.client.sendDestination(
        widget.vehicle.vin,
        address: d.direccion,
        addressName: d.nombre,
        latitude: d.lat,
        longitude: d.lon,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(es
            ? 'Destino enviado. Aparecera en el navegador del coche.'
            : 'Destination sent. It will appear on the car navigation.'),
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(es ? 'Error al enviar: $e' : 'Send failed: $e'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Enviar destino al coche' : 'Send destination to car')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      hintText: es ? 'Direccion, lugar, negocio...' : 'Address, place, business...',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _buscando ? null : _buscar,
                  icon: const Icon(Icons.search),
                ),
              ]),
              const SizedBox(height: 16),
              if (_buscando)
                const Center(
                  child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    es ? 'Error en la busqueda: $_error' : 'Search error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (!_buscando && _error == null && _resultados.isEmpty && _ctrl.text.isNotEmpty)
                Text(
                  es ? 'Sin resultados.' : 'No results.',
                  style: const TextStyle(color: Colors.grey),
                ),
              for (final d in _resultados)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(d.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(d.direccion, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.send_outlined),
                    onTap: _enviando ? null : () => _confirmarYEnviar(d),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                es
                    ? 'El destino llega al navegador del coche sin pedir PIN. Busqueda por OpenStreetMap.'
                    : 'The destination reaches the car navigation without asking for the PIN. Search by OpenStreetMap.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          if (_enviando)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
