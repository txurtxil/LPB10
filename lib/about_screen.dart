import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'l10n/generated/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  // Respaldo si no se puede leer la version real del paquete.
  static const String kDisplayVersion = '3.60.183';

  /// Version real del paquete instalado (la del build), no una constante
  /// manual que se quedaba desactualizada entre releases.
  static Future<String> appVersion() async {
    try {
      final i = await PackageInfo.fromPlatform();
      if (i.version.isNotEmpty) return i.version;
    } catch (_) {}
    return kDisplayVersion;
  }

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = AboutScreen.kDisplayVersion;

  @override
  void initState() {
    super.initState();
    AboutScreen.appVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }
  static const _releasesUrl = 'https://github.com/txurtxil/LPB10/releases';
  static const _webUrl = 'https://txurtxil.github.io/LPB10/';
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
              children: [
                const Text('LMB10', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('v$_version', style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                    ? 'Pagina web del proyecto'
                    : 'Project website',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => launchUrl(Uri.parse(_webUrl), mode: LaunchMode.externalApplication),
              child: const Text(
                _webUrl,
                style: TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline),
              ),
            ),
            const SizedBox(height: 24),
            Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Creditos y agradecimientos'
                    : 'Credits and thanks',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'La comunicacion con la nube de Leapmotor es un port a Dart del cliente de referencia markoceri/leapmotor-api, y los certificados mTLS salen del material publicado por el mismo autor en markoceri/leapmotor-certs. Gracias, markoceri, por ambos.'
                  : 'The Leapmotor cloud communication is a Dart port of the reference client markoceri/leapmotor-api, and the mTLS certificates come from material published by the same author at markoceri/leapmotor-certs. Thanks, markoceri, for both.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _enlaceCredito('https://github.com/markoceri/leapmotor-api'),
            _enlaceCredito('https://github.com/markoceri/leapmotor-certs'),
            const SizedBox(height: 12),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'Los videos de los bajos del B10 del canal EvCanariasB10, de Dani (@EVCanariasDani) con el mecanico Pedro (@P_38_87), han sido documentacion clave para entender este coche. Gracias a ambos.'
                  : 'The B10 underbody videos from the EvCanariasB10 channel, by Dani (@EVCanariasDani) with mechanic Pedro (@P_38_87), have been key documentation to understand this car. Thanks to both.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _enlaceCredito('https://www.youtube.com/@EvCanariasB10'),
            const SizedBox(height: 12),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'El grupo de Telegram LEAPMOTOR B10 CLUB, donde se reunen los betatesters: pruebas, reportes de compatibilidad y soporte a los usuarios. La app es mejor gracias a ellos.'
                  : 'The LEAPMOTOR B10 CLUB Telegram group, where the beta testers gather: testing, compatibility reports and user support. The app is better thanks to them.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _enlaceCredito('https://t.me/LEAPMOTORB10CLUB'),
            const SizedBox(height: 12),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? '@juanludetoledo: gracias por su apoyo al proyecto. Si te interesa el B10 y el mundo electrico, apoya su canal de YouTube.'
                  : '@juanludetoledo: thanks for supporting the project. If you are into the B10 and the EV world, support his YouTube channel.',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            _enlaceCredito('https://youtube.com/@juanludetoledo'),
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

/// Enlace de la seccion de creditos: abre siempre en el navegador o en la
/// app correspondiente (LaunchMode.externalApplication), nunca en WebView.
Widget _enlaceCredito(String url) {
  return InkWell(
    onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        url,
        style: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline, fontSize: 13),
      ),
    ),
  );
}
