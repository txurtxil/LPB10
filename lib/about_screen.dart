import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/generated/app_localizations.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Version visible de la app. La actualiza release_apk.sh en cada release.
  static const String kDisplayVersion = '3.60.29';
  static const _releasesUrl = 'https://github.com/txurtxil/LPB10/releases';
  static const _autismUrl = 'https://es.wikipedia.org/wiki/Trastornos_del_espectro_autista';
  static const _kofiUrl = 'https://ko-fi.com/txurtxil';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.aboutScreenTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: const [
                Text('LMB10', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Text('v$kDisplayVersion', style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.appTagline, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.authorLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('SurferRule'),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.licenseLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.licenseValue),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.repoLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => launchUrl(Uri.parse(_releasesUrl), mode: LaunchMode.externalApplication),
              child: const Text(
                _releasesUrl,
                style: TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 24),
            Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Sobre el autismo'
                    : 'About autism',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'Esta app se desarrolla en parte para apoyar un proyecto personal sobre autismo. El autismo es una forma distinta de percibir el mundo, no una enfermedad. Comprenderlo y respetarlo ayuda a muchas personas y sus familias.'
                  : 'This app is developed partly to support a personal project about autism. Autism is a different way of perceiving the world, not an illness. Understanding and respecting it helps many people and their families.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => launchUrl(Uri.parse(_autismUrl), mode: LaunchMode.externalApplication),
              child: Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Que es el autismo (Wikipedia)'
                    : 'What is autism (Wikipedia)',
                style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Apoyar el desarrollo'
                    : 'Support development',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'LMB10 es gratis, de codigo abierto y no tiene publicidad ni rastreadores. Si te resulta util y te apetece invitarme a un cafe, se agradece mucho. Es completamente opcional: no desbloquea nada dentro de la app ni da soporte prioritario.'
                  : 'LMB10 is free, open source, with no ads or trackers. If it is useful to you and you feel like buying me a coffee, it is much appreciated. It is entirely optional: it unlocks nothing inside the app and buys no priority support.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(_kofiUrl),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.coffee_outlined, size: 18),
              label: const Text('ko-fi.com/txurtxil'),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.disclaimerText,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
