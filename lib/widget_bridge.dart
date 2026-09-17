// widget_bridge.dart - Fachada de home_widget que no-op en iOS (v158).
//
// Los widgets (QuickWidgetProvider, BatteryWidgetProvider) solo existen en
// Android: no hay extension de widget para iOS. Pero home_widget, en iOS,
// exige setAppGroupId() con un App Group REAL (entitlement de Apple
// configurado en Xcode) y, sin el, TODA llamada lanza
// PlatformException(-7, AppGroupId not set). La primera de ellas iba sin
// try/catch (_pushToHomeWidget, dato 'soc') y el error acababa de cartel
// amarillo en el dashboard.
//
// Solucion: ningun fichero toca HomeWidget directamente; todo pasa por
// LmWidget, que en iOS no hace nada (getWidgetData devuelve null y los
// llamantes ya tienen sus fallbacks; widgetClicked es un stream vacio).
// Si algun dia se crea la extension de widget para iOS, solo hay que
// cambiar este fichero.
//
// OJO: los try/catch que ya rodeaban estas llamadas en los llamantes se
// mantienen; esta fachada solo anade la puerta de plataforma, no traga
// errores nuevos.

import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

class LmWidget {
  static Future<T?> getWidgetData<T>(String key) => Platform.isAndroid
      ? HomeWidget.getWidgetData<T>(key)
      : Future<T?>.value(null);

  static Future<void> saveWidgetData<T>(String key, T? value) async {
    if (Platform.isAndroid) await HomeWidget.saveWidgetData<T>(key, value);
  }

  static Future<void> updateWidget({String? androidName}) async {
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(androidName: androidName);
    }
  }

  static Future<Uri?> initiallyLaunchedFromHomeWidget() => Platform.isAndroid
      ? HomeWidget.initiallyLaunchedFromHomeWidget()
      : Future<Uri?>.value(null);

  static void registerInteractivityCallback(
      Future<void> Function(Uri?) callback) {
    if (Platform.isAndroid) {
      HomeWidget.registerInteractivityCallback(callback);
    }
  }

  static Stream<Uri?> get widgetClicked => Platform.isAndroid
      ? HomeWidget.widgetClicked
      : const Stream<Uri?>.empty();
}
