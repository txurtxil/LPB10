import 'package:flutter/material.dart';
import 'leapmotor_engine.dart';
import 'l10n/generated/app_localizations.dart';

class MessagesScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  const MessagesScreen({super.key, required this.client});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.client.getMessages(1, 30);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(result['messages'] as List);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtDate(dynamic sendTime) {
    if (sendTime == null) return '';
    final ms = sendTime is num ? sendTime.toInt() : int.tryParse(sendTime.toString());
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.messagesScreenTitle),
        actions: [
          IconButton(
            icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red))))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(child: Text(AppLocalizations.of(context)!.noMessages))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, i) {
                        final m = _messages[i];
                        final unread = m['readFlag'] == 0;
                        return ListTile(
                          leading: Icon(unread ? Icons.mark_email_unread : Icons.mark_email_read, color: unread ? Colors.amber : Colors.grey),
                          title: Text(m['title']?.toString() ?? AppLocalizations.of(context)!.noTitlePlaceholder, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text('${m['message'] ?? ''}\n${_fmtDate(m['sendTime'])}'),
                          isThreeLine: true,
                        );
                      },
                    ),
    );
  }
}
