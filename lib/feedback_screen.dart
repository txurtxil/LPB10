// feedback_screen.dart — Enviar feedback o reporte de bug DIRECTO al repo de
// GitHub (issues de txurtxil/LPB10). Rellena version y modelo automaticamente
// y etiqueta el issue (bug/enhancement). El token vive en feedback_token.dart
// (gitignored, permiso minimo issues:write) para que no se publique en el repo.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'feedback_token.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _titulo = TextEditingController();
  final _desc = TextEditingController();
  final _modelo = TextEditingController();
  String _tipo = 'bug';
  bool _enviando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    _modelo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (kFeedbackToken.isEmpty || kFeedbackToken.contains('PEGAR')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'El envio aun no esta habilitado en esta version.'
              : 'Sending is not enabled yet in this build.')));
      return;
    }
    if (_titulo.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'Rellena titulo y descripcion.'
              : 'Fill in title and description.')));
      return;
    }
    setState(() => _enviando = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final cuerpo = '**Version**: ${info.version}+${info.buildNumber}\n'
          '**Modelo**: ${_modelo.text.trim().isEmpty ? '?' : _modelo.text.trim()}\n\n'
          '${_desc.text.trim()}';
      final resp = await http.IOClient().post(
        Uri.parse('https://api.github.com/repos/txurtxil/LPB10/issues'),
        headers: {
          'Authorization': 'Bearer $kFeedbackToken',
          'Accept': 'application/vnd.github+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': '[${_tipo == 'bug' ? 'BUG' : 'IDEA'}] ${_titulo.text.trim()}',
          'body': cuerpo,
          'labels': [_tipo == 'bug' ? 'bug' : 'enhancement'],
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'Enviado. Gracias por el feedback!'
                : 'Sent. Thanks for the feedback!')));
        _titulo.clear();
        _desc.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'Error del servidor (${resp.statusCode}). Intentalo mas tarde.'
                : 'Server error (${resp.statusCode}). Try later.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'Sin conexion. Intentalo mas tarde.'
                : 'No connection. Try later.')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'Enviar feedback' : 'Send feedback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(es
              ? 'Se publicara directamente como issue en el repositorio del proyecto (visible para el equipo).'
              : 'This will be published directly as an issue in the project repository (visible to the team).'),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                  value: 'bug',
                  label: Text(es ? 'Bug' : 'Bug'),
                  icon: const Icon(Icons.bug_report)),
              ButtonSegment(
                  value: 'idea',
                  label: Text(es ? 'Mejora' : 'Enhancement'),
                  icon: const Icon(Icons.lightbulb_outline)),
            ],
            selected: {_tipo},
            onSelectionChanged: (s) => setState(() => _tipo = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titulo,
            decoration: InputDecoration(
              labelText: es ? 'Titulo' : 'Title',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modelo,
            decoration: InputDecoration(
              labelText: es ? 'Modelo de coche (opcional)' : 'Car model (optional)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: es ? 'Descripcion' : 'Description',
              hintText: es
                  ? 'Pasos para reproducirlo / que esperabas / que paso...'
                  : 'Steps to reproduce / expected / actual...',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: _enviando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: Text(es ? 'Enviar' : 'Send'),
          ),
        ],
      ),
    );
  }
}
