import 'package:flutter/material.dart';

import 'car_log_bridge.dart';
import 'leapmotor_engine.dart';

/// Invitaciones de comparticion de coche recibidas por esta cuenta
/// (sharecar/getsharemsg + setokmsg, v217). Aceptar/rechazar toca solo la
/// relacion de comparticion de la cuenta; no manda nada al coche.
class ShareScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  const ShareScreen({super.key, required this.client});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  late Future<List<ShareInvitation>> _future;

  @override
  void initState() {
    super.initState();
    CarLogBridge.log('SHARE peticion getsharemsg');
    _future = widget.client.getShareInvitations();
    _future.then((list) {
      CarLogBridge.log('SHARE ok: invitaciones=${list.length}');
    }).catchError((e) {
      CarLogBridge.log('SHARE FALLO: $e');
    });
  }

  Future<void> _answer(ShareInvitation inv, bool accept) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    try {
      await widget.client.answerShareInvitation(inv, accept: accept);
      CarLogBridge.log(
          'SHARE ${accept ? 'aceptada' : 'rechazada'}: ${inv.vin} de ${inv.ownerName}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? (es ? 'Invitacion aceptada' : 'Invitation accepted')
              : (es ? 'Invitacion rechazada' : 'Invitation declined'))));
      setState(() {
        _future = widget.client.getShareInvitations();
      });
    } catch (e) {
      CarLogBridge.log('SHARE FALLO setokmsg: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'Coches compartidos' : 'Shared vehicles')),
      body: FutureBuilder<List<ShareInvitation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: ${snap.error}', textAlign: TextAlign.center),
            ));
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                es
                    ? 'No hay invitaciones de comparticion pendientes.\nCuando otro usuario te comparta su coche, aparecera aqui.'
                    : 'No pending share invitations.\nWhen another user shares a car with you, it will appear here.',
                textAlign: TextAlign.center,
              ),
            ));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final inv = list[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.carAlias.isNotEmpty ? inv.carAlias : inv.vin,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${es ? 'De' : 'From'}: ${inv.ownerName.isNotEmpty ? inv.ownerName : '?'} · ${inv.vin}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (inv.carType.isNotEmpty)
                        Text('carType: ${inv.carType}',
                            style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (inv.hasBasic)
                            Chip(label: Text(es ? 'Basico' : 'Basic')),
                          if (inv.hasVehicleControl)
                            Chip(label: Text(es ? 'Control' : 'Control')),
                          if (inv.hasPositioning)
                            Chip(label: Text(es ? 'Posicion' : 'Location')),
                          if (inv.hasMileageEnergy)
                            Chip(label: Text(es ? 'Consumo' : 'Energy')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _answer(inv, false),
                            child: Text(es ? 'Rechazar' : 'Decline'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _answer(inv, true),
                            child: Text(es ? 'Aceptar' : 'Accept'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
