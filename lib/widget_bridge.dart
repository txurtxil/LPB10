// widget_bridge.dart - Fachada de home_widget (v158: no-op en iOS;
// v161: iOS activo con la extension LmBatteryWidget).
//
// Android: QuickWidgetProvider y BatteryWidgetProvider leen SharedPreferences
// via home_widget. iOS: la extension WidgetKit LmBatteryWidget lee el
// UserDefaults del App Group compartido; home_widget exige setAppGroupId()
// con un App Group REAL (entitlement com.apple.security.application-groups
// en Runner.entitlements y en la extension, configurado por
// tool/ios_add_widget_target.rb). Sin el, TODA llamada lanza
// PlatformException(-7, AppGroupId not set) — el cartel amarillo original
// del dashboard vino de ahi.
//
// Defensa en profundidad: aun con la extension creada, si el App Group no
// esta registrado en la cuenta de Apple del desarrollador (p. ej. build sin
// firmar o grupo no dado de alta en el portal), setAppGroupId y las
// escrituras fallan. Esta fachada traga SOLO esos fallos de widget en iOS
// (log por consola y a seguir): el widget es un extra, nunca debe romper la
// app. En Android se mantiene el comportamiento original sin tragar nada.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class LmWidget {
  // Mismo App Group en Runner.entitlements, LmBatteryWidget.entitlements,
  // el UserDefaults(suiteName:) del widget Swift y aqui.
  static const String _kIosAppGroup = 'group.com.txurtxil.lpb10';
  // Debe coincidir con el `kind:` del StaticConfiguration del widget Swift.
  static const String _kIosWidgetName = 'LmBatteryWidget';
  static bool _grupoIosListo = false;

  static Future<bool> _asegurarGrupoIos() async {
    if (_grupoIosListo) return true;
    try {
      await HomeWidget.setAppGroupId(_kIosAppGroup);
      _grupoIosListo = true;
      return true;
    } catch (e) {
      debugPrint('LmWidget: App Group iOS no disponible ($e)');
      return false;
    }
  }

  static Future<T?> getWidgetData<T>(String key) async {
    if (Platform.isAndroid) return HomeWidget.getWidgetData<T>(key);
    if (Platform.isIOS && await _asegurarGrupoIos()) {
      try {
        return await HomeWidget.getWidgetData<T>(key);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<void> saveWidgetData<T>(String key, T? value) async {
    if (Platform.isAndroid) {
      await HomeWidget.saveWidgetData<T>(key, value);
      return;
    }
    if (Platform.isIOS && await _asegurarGrupoIos()) {
      try {
        await HomeWidget.saveWidgetData<T>(key, value);
      } catch (_) {}
    }
  }

  static Future<void> updateWidget({String? androidName}) async {
    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(androidName: androidName);
      return;
    }
    if (Platform.isIOS && await _asegurarGrupoIos()) {
      try {
        await HomeWidget.updateWidget(iOSName: _kIosWidgetName);
      } catch (_) {}
    }
  }

  // De aqui para abajo sigue siendo solo Android: la extension iOS no tiene
  // interactividad (botones) en esta version; el toque abre la app via
  // widgetURL y el esquema lmb10:// declarado en Runner/Info.plist.
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
