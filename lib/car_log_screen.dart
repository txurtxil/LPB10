import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CarLogScreen extends StatefulWidget {
  const CarLogScreen({super.key});
  @override
  State<CarLogScreen> createState() => _CarLogScreenState();
}

class _CarLogScreenState extends State<CarLogScreen> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _logFile() async {
    final base = await getApplicationDocumentsDirectory();
    return File('${base.path}/lmb10_history/carlog.txt');
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final f = await _logFile();
      if (await f.exists()) {
        _content = await f.readAsString();
      } else {
        _content = '(sin registros todavia)\n\nConecta al coche por Android Auto y vuelve aqui.';
      }
    } catch (e) {
      _content = 'Error leyendo el log: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _clear() async {
    try {
      final f = await _logFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _load();
  }

  Future<void> _share() async {
    try {
      final f = await _logFile();
      if (await f.exists()) {
        await Share.shareXFiles([XFile(f.path)], text: 'LMB10 car log');
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Log del coche' : 'Car log'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(icon: const Icon(Icons.share), onPressed: _share),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _clear),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                _content,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
    );
  }
}
