#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

cat > lib/welcome_screen.dart << 'DARTEOF'
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

const _welcomeStorage = FlutterSecureStorage();
const String kWelcomeAcceptedKey = 'lm_welcome_accepted_v1';

Future<bool> welcomeAccepted() async {
  try {
    return (await _welcomeStorage.read(key: kWelcomeAcceptedKey)) == '1';
  } catch (_) {
    return false;
  }
}

Future<void> setWelcomeAccepted() async {
  await _welcomeStorage.write(key: kWelcomeAcceptedKey, value: '1');
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onAccept});
  final VoidCallback onAccept;

  static const _autismUrl =
      'https://es.wikipedia.org/wiki/Trastornos_del_espectro_autista';

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';

    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Text(body,
                  style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'Bienvenido a LMB10' : 'Welcome to LMB10'),
          automaticallyImplyLeading: false),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                section(
                  es ? 'Aplicacion no oficial' : 'Unofficial app',
                  es
                      ? 'LMB10 es una aplicacion independiente, sin relacion ni respaldo de Leapmotor. Leapmotor y sus marcas pertenecen a sus titulares. La app no distribuye ningun material de Leapmotor: el certificado de cliente lo aporta cada usuario bajo su responsabilidad.'
                      : 'LMB10 is an independent app, not affiliated with or endorsed by Leapmotor. Leapmotor and its trademarks belong to their owners. The app distributes no Leapmotor material: each user supplies their own client certificate at their own responsibility.',
                ),
                section(
                  es ? 'Sin garantia' : 'No warranty',
                  es
                      ? 'Se ofrece "tal cual", sin garantia de ningun tipo. El autor no se hace responsable de danos al vehiculo, a la bateria, de perdida de datos, ni de incidencias con tu cuenta derivadas del uso. Usala con criterio y nunca mientras conduces.'
                      : 'Provided "as is", without warranty of any kind. The author is not liable for damage to the vehicle or battery, data loss, or account issues arising from its use. Use it sensibly and never while driving.',
                ),
                section(
                  es ? 'Usa una segunda cuenta' : 'Use a second account',
                  es
                      ? 'LMB10 es complementaria a la app oficial, no la sustituye. Se recomienda usarla con una cuenta secundaria: la app oficial suele permitir solo una sesion activa, asi que entrar aqui con tu cuenta principal puede cerrar tu sesion en la oficial (y viceversa).\n\nComo hacerlo, a grandes rasgos: en la app oficial de Leapmotor, invita o anade a un familiar/miembro al vehiculo (crea o usa otra cuenta con su propio correo), acepta la invitacion, y usa esos datos para iniciar sesion en LMB10. Deja tu cuenta principal para la app oficial. Los menus exactos dependen de tu version de la app oficial y del pais.'
                      : 'LMB10 complements the official app, it does not replace it. Using a secondary account is recommended: the official app usually allows only one active session, so signing in here with your main account may log you out of the official one (and vice versa).\n\nHow to do it, broadly: in the official Leapmotor app, invite or add a family member to the vehicle (create or use another account with its own email), accept the invitation, and use those credentials to sign in to LMB10. Keep your main account for the official app. Exact menus depend on your official app version and country.',
                ),
                section(
                  es ? 'Privacidad' : 'Privacy',
                  es
                      ? 'Tus datos no salen del dispositivo. El certificado se guarda cifrado localmente y no se incluye en las copias de seguridad.'
                      : 'Your data never leaves the device. The certificate is stored encrypted locally and is not included in backups.',
                ),
                const Divider(height: 28),
                Text(
                  es ? 'Sobre el autismo' : 'About autism',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  es
                      ? 'Esta app se desarrolla en parte para apoyar un proyecto personal sobre autismo. El autismo es una forma distinta de percibir y relacionarse con el mundo, no una enfermedad. Comprenderlo y respetarlo hace la vida mas facil a muchas personas y sus familias. Este enlace es solo informativo; LMB10 no esta afiliada a ninguna entidad.'
                      : 'This app is developed partly to support a personal project about autism. Autism is a different way of perceiving and relating to the world, not an illness. Understanding and respecting it makes life easier for many people and their families. This link is informational only; LMB10 is not affiliated with any organization.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(_autismUrl),
                      mode: LaunchMode.externalApplication),
                  child: Text(
                    es
                        ? 'Que es el autismo (Wikipedia)'
                        : 'What is autism (Wikipedia)',
                    style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        decoration: TextDecoration.underline,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await setWelcomeAccepted();
                    onAccept();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(es ? 'Acepto y continuo' : 'I accept and continue'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
DARTEOF

echo "welcome_screen.dart creado. Analizando..."
flutter analyze lib/welcome_screen.dart 2>&1 | tail -15
