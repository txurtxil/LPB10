// maintenance_ticket_screen.dart — Previsualizar e imprimir/compartir el
// informe de mantenimiento. Mismo patron que ticket_screen.dart, sin el
// selector de rango: el informe de mantenimiento es del estado ACTUAL, no
// de un periodo.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'maintenance_ticket.dart';
import 'ticket_printer.dart';

class MaintenanceTicketScreen extends StatefulWidget {
  const MaintenanceTicketScreen({super.key, this.nickname});
  final String? nickname;

  @override
  State<MaintenanceTicketScreen> createState() => _MaintenanceTicketScreenState();
}

class _MaintenanceTicketScreenState extends State<MaintenanceTicketScreen> {
  String _preview = '';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _rebuild();
  }

  Future<void> _rebuild() async {
    setState(() => _busy = true);
    final t = await buildMaintenanceTicket(nickname: widget.nickname);
    if (!mounted) return;
    setState(() {
      _preview = t;
      _busy = false;
    });
  }

  Future<void> _print() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final ok = await TicketPrinter.printOrShare(_preview);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (es ? 'Enviado a la impresora' : 'Sent to printer')
            : (es ? 'No se pudo imprimir' : 'Print failed'))));
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Informe de mantenimiento' : 'Maintenance report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: es ? 'Actualizar' : 'Refresh',
            onPressed: _busy ? null : _rebuild,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBEF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: _busy
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: SelectableText(
                        _preview,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.black,
                            height: 1.25),
                      ),
                    ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Clipboard.setData(ClipboardData(text: _preview)),
                      icon: const Icon(Icons.copy),
                      label: Text(es ? 'Copiar' : 'Copy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _print,
                      icon: const Icon(Icons.print),
                      label: Text(es ? 'Imprimir' : 'Print'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
