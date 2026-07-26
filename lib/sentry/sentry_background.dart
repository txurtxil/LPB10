// sentry_background.dart
// AÑADE UNA SOLA LINEA a tu callback de WorkManager existente (~15 min):
//
//   import 'sentry/sentry_background.dart';   // ajusta la ruta
//   ...
//   await sentryBackgroundPoll();
//
// No hace nada si el Centinela no esta armado. Nunca lanza excepciones.

import 'sentry_adapter.dart';
import 'sentry_engine.dart';
import 'sentry_store.dart';

Future<void> sentryBackgroundPoll() async {
  try {
    final store = SentryStore();
    if (!await store.loadArmed()) return;
    final client = await buildSentryClient();
    await SentryEngine(client: client, store: store).pollOnce();
  } catch (_) {
    // silencioso: el siguiente ciclo lo reintenta
  }
}
