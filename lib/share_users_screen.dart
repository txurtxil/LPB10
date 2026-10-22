import 'package:flutter/material.dart';

import 'car_log_bridge.dart';
import 'leapmotor_engine.dart';

/// Usuarios con acceso a MI coche (owner-side, v218). Endpoints candidatos
/// (addshare/getsharelist/cancelshare): el carlog registra la respuesta
/// cruda; si la API devuelve 404/400, el mensaje revela el path correcto
/// para la siguiente iteracion.
class ShareUsersScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  const ShareUsersScreen({super.key, required this.client, required this.vehicle});

  @override
  State<ShareUsersScreen> createState() => _ShareUsersScreenState();
}

class _ShareUsersScreenState extends State<ShareUsersScreen> {
  late Future<List<SharedUser>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    CarLogBridge.log('SHARE-OWN peticion getsharelist vin=${widget.vehicle.vin}');
    _future = widget.client.getSharedUsers(widget.vehicle.vin);
  }

  Future<void> _revoke(SharedUser u) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    try {
      await widget.client.shareCarRevoke(widget.vehicle.vin, u.shareUserId, email: u.email, mobileNumber: u.mobileNumber);
      CarLogBridge.log('SHARE-OWN revocado: ${u.shareUserId}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es ? 'Acceso revocado' : 'Access revoked')));
      setState(_reload);
    } catch (e) {
      CarLogBridge.log('SHARE-OWN FALLO revoke: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _invite() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(es ? 'Invitar usuario' : 'Invite user'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
              labelText: es ? 'Email de la cuenta invitada' : 'Invitee account email'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(es ? 'Cancelar' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(es ? 'Invitar' : 'Invite')),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await widget.client.shareCarInvite(widget.vehicle.vin, email);
      CarLogBridge.log('SHARE-OWN invitado: $email');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es ? 'Invitacion enviada a $email' : 'Invitation sent to $email')));
      setState(_reload);
    } catch (e) {
      CarLogBridge.log('SHARE-OWN FALLO invite: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Usuarios con acceso' : 'Users with access')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add),
        label: Text(es ? 'Invitar' : 'Invite'),
      ),
      body: FutureBuilder<List<SharedUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(es
                        ? 'El endpoint candidato no respondio. Mira el carlog: la respuesta cruda indica el path correcto.'
                        : 'Candidate endpoint failed. Check the carlog: the raw response shows the correct path.'),
                    const SizedBox(height: 12),
                    Text('${snap.error}', textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed: () => setState(_reload),
                        child: Text(es ? 'Reintentar' : 'Retry')),
                  ],
                ),
              ),
            );
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
                child: Text(es
                    ? 'Este coche no se comparte con nadie todavia.'
                    : 'This car is not shared with anyone yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final u = list[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(u.displayName),
                  subtitle: Text([
                    if (u.email.isNotEmpty) u.email,
                    if (u.mobileNumber.isNotEmpty) u.mobileNumber,
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.red),
                    tooltip: es ? 'Revocar acceso' : 'Revoke access',
                    onPressed: u.shareUserId.isEmpty ? null : () => _revoke(u),
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
