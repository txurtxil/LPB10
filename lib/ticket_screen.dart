// ticket_screen.dart — Elegir periodo, previsualizar e imprimir el ticket.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ticket_printer.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, this.nickname});
  final String? nickname;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  late DateTime _from;
  late DateTime _to;
  String _preview = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = now;
    _from = now.subtract(const Duration(days: 6));
    _rebuild();
  }

  Future<void> _rebuild() async {
    setState(() => _busy = true);
    final t = await buildEfficiencyTicket(
        from: _from, to: _to, nickname: widget.nickname);
    if (!mounted) return;
    setState(() {
      _preview = t;
      _busy = false;
    });
  }

  void _preset(int days) {
    final now = DateTime.now();
    setState(() {
      _to = now;
      _from = now.subtract(Duration(days: days - 1));
    });
    _rebuild();
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (r == null) return;
    setState(() {
      _from = r.start;
      _to = r.end;
    });
    _rebuild();
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
      appBar: AppBar(title: Text(es ? 'Ticket de eficiencia' : 'Efficiency ticket')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(onPressed: () => _preset(7), child: const Text('7 d')),
                OutlinedButton(onPressed: () => _preset(30), child: const Text('30 d')),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(es ? 'Rango' : 'Range'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 12),
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
