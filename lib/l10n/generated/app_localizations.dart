import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'LMB10'**
  String get appTitle;

  /// No description provided for @loginScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesion'**
  String get loginScreenTitle;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contrasena'**
  String get passwordLabel;

  /// No description provided for @pinLabel.
  ///
  /// In es, this message translates to:
  /// **'PIN del vehiculo'**
  String get pinLabel;

  /// No description provided for @pinHelper.
  ///
  /// In es, this message translates to:
  /// **'Necesario para bloquear/desbloquear, clima, asientos, etc.'**
  String get pinHelper;

  /// No description provided for @rememberPinTitle.
  ///
  /// In es, this message translates to:
  /// **'Recordar PIN en este dispositivo'**
  String get rememberPinTitle;

  /// No description provided for @rememberPinSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Se guarda cifrado localmente (flutter_secure_storage).'**
  String get rememberPinSubtitle;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Login'**
  String get loginButton;

  /// No description provided for @dashboardDefaultTitle.
  ///
  /// In es, this message translates to:
  /// **'Leapmotor'**
  String get dashboardDefaultTitle;

  /// No description provided for @refreshTooltip.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get refreshTooltip;

  /// No description provided for @settingsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Ajustes, logs y backups'**
  String get settingsTooltip;

  /// No description provided for @aboutTooltip.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get aboutTooltip;

  /// No description provided for @logoutTooltip.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesion'**
  String get logoutTooltip;

  /// No description provided for @tileBattery.
  ///
  /// In es, this message translates to:
  /// **'Bateria'**
  String get tileBattery;

  /// No description provided for @tileAutonomy.
  ///
  /// In es, this message translates to:
  /// **'Autonomia'**
  String get tileAutonomy;

  /// No description provided for @tileLock.
  ///
  /// In es, this message translates to:
  /// **'Cerradura'**
  String get tileLock;

  /// No description provided for @lockedLabel.
  ///
  /// In es, this message translates to:
  /// **'Cerrado'**
  String get lockedLabel;

  /// No description provided for @unlockedLabel.
  ///
  /// In es, this message translates to:
  /// **'Abierto'**
  String get unlockedLabel;

  /// No description provided for @tileChargeState.
  ///
  /// In es, this message translates to:
  /// **'Estado carga'**
  String get tileChargeState;

  /// No description provided for @chargingLabel.
  ///
  /// In es, this message translates to:
  /// **'Cargando'**
  String get chargingLabel;

  /// No description provided for @notChargingLabel.
  ///
  /// In es, this message translates to:
  /// **'Sin carga'**
  String get notChargingLabel;

  /// No description provided for @disconnectedLabel.
  ///
  /// In es, this message translates to:
  /// **'Desconectado'**
  String get disconnectedLabel;

  /// No description provided for @tileChargeCable.
  ///
  /// In es, this message translates to:
  /// **'Cable carga'**
  String get tileChargeCable;

  /// No description provided for @connectedLabel.
  ///
  /// In es, this message translates to:
  /// **'Conectado'**
  String get connectedLabel;

  /// No description provided for @disconnectedShortLabel.
  ///
  /// In es, this message translates to:
  /// **'Desconect.'**
  String get disconnectedShortLabel;

  /// No description provided for @tileThermalMgmt.
  ///
  /// In es, this message translates to:
  /// **'Gestion termica'**
  String get tileThermalMgmt;

  /// No description provided for @activeLabel.
  ///
  /// In es, this message translates to:
  /// **'Activa'**
  String get activeLabel;

  /// No description provided for @normalLabel.
  ///
  /// In es, this message translates to:
  /// **'Normal'**
  String get normalLabel;

  /// No description provided for @tileClimate.
  ///
  /// In es, this message translates to:
  /// **'Clima'**
  String get tileClimate;

  /// No description provided for @onLabel.
  ///
  /// In es, this message translates to:
  /// **'Encendido'**
  String get onLabel;

  /// No description provided for @offLabel.
  ///
  /// In es, this message translates to:
  /// **'Apagada'**
  String get offLabel;

  /// No description provided for @tileTrunk.
  ///
  /// In es, this message translates to:
  /// **'Maletero'**
  String get tileTrunk;

  /// No description provided for @openLabel.
  ///
  /// In es, this message translates to:
  /// **'Abierto'**
  String get openLabel;

  /// No description provided for @closedLabel.
  ///
  /// In es, this message translates to:
  /// **'Cerrado'**
  String get closedLabel;

  /// No description provided for @tileSentry.
  ///
  /// In es, this message translates to:
  /// **'Centinela'**
  String get tileSentry;

  /// No description provided for @activeShortLabel.
  ///
  /// In es, this message translates to:
  /// **'Activo'**
  String get activeShortLabel;

  /// No description provided for @inactiveLabel.
  ///
  /// In es, this message translates to:
  /// **'Inactivo'**
  String get inactiveLabel;

  /// No description provided for @controlsButton.
  ///
  /// In es, this message translates to:
  /// **'Controles del vehiculo'**
  String get controlsButton;

  /// No description provided for @guardModeButton.
  ///
  /// In es, this message translates to:
  /// **'Modo Vigilancia (experimental)'**
  String get guardModeButton;

  /// No description provided for @preconditioningButton.
  ///
  /// In es, this message translates to:
  /// **'Precondicionado'**
  String get preconditioningButton;

  /// No description provided for @messagesButton.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get messagesButton;

  /// No description provided for @exportButton.
  ///
  /// In es, this message translates to:
  /// **'Exportar datos (JSON anonimizado)'**
  String get exportButton;

  /// No description provided for @debugButton.
  ///
  /// In es, this message translates to:
  /// **'Ver estado completo (debug)'**
  String get debugButton;

  /// No description provided for @pinDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'PIN del vehiculo'**
  String get pinDialogTitle;

  /// No description provided for @pinDialogCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get pinDialogCancel;

  /// No description provided for @pinDialogAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get pinDialogAccept;

  /// No description provided for @noLocationData.
  ///
  /// In es, this message translates to:
  /// **'Sin datos de ubicacion'**
  String get noLocationData;

  /// No description provided for @controlsScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Controles del vehiculo'**
  String get controlsScreenTitle;

  /// No description provided for @sectionSentry.
  ///
  /// In es, this message translates to:
  /// **'Centinela'**
  String get sectionSentry;

  /// No description provided for @sectionActions.
  ///
  /// In es, this message translates to:
  /// **'Acciones'**
  String get sectionActions;

  /// No description provided for @sectionClimate.
  ///
  /// In es, this message translates to:
  /// **'Climatizacion'**
  String get sectionClimate;

  /// No description provided for @sectionComfort.
  ///
  /// In es, this message translates to:
  /// **'Confort'**
  String get sectionComfort;

  /// No description provided for @sectionSunshadeWindows.
  ///
  /// In es, this message translates to:
  /// **'Persiana y ventanas'**
  String get sectionSunshadeWindows;

  /// No description provided for @sectionSpeedLimit.
  ///
  /// In es, this message translates to:
  /// **'Limite de velocidad'**
  String get sectionSpeedLimit;

  /// No description provided for @sectionBattery.
  ///
  /// In es, this message translates to:
  /// **'Bateria'**
  String get sectionBattery;

  /// No description provided for @sectionSeats.
  ///
  /// In es, this message translates to:
  /// **'Asientos'**
  String get sectionSeats;

  /// No description provided for @actionSentryOn.
  ///
  /// In es, this message translates to:
  /// **'Centinela ON'**
  String get actionSentryOn;

  /// No description provided for @actionSentryOff.
  ///
  /// In es, this message translates to:
  /// **'Centinela OFF'**
  String get actionSentryOff;

  /// No description provided for @actionLock.
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get actionLock;

  /// No description provided for @actionUnlock.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get actionUnlock;

  /// No description provided for @actionTrunkOpen.
  ///
  /// In es, this message translates to:
  /// **'Maletero abrir'**
  String get actionTrunkOpen;

  /// No description provided for @actionTrunkClose.
  ///
  /// In es, this message translates to:
  /// **'Maletero cerrar'**
  String get actionTrunkClose;

  /// No description provided for @actionFindCar.
  ///
  /// In es, this message translates to:
  /// **'Localizar'**
  String get actionFindCar;

  /// No description provided for @actionUnlockCharger.
  ///
  /// In es, this message translates to:
  /// **'Desbloq. cargador'**
  String get actionUnlockCharger;

  /// No description provided for @actionQuickHeat.
  ///
  /// In es, this message translates to:
  /// **'Calentar rapido'**
  String get actionQuickHeat;

  /// No description provided for @actionQuickCool.
  ///
  /// In es, this message translates to:
  /// **'Enfriar rapido'**
  String get actionQuickCool;

  /// No description provided for @actionDefrost.
  ///
  /// In es, this message translates to:
  /// **'Desempanar parabrisas'**
  String get actionDefrost;

  /// No description provided for @actionAcOff.
  ///
  /// In es, this message translates to:
  /// **'Apagar clima'**
  String get actionAcOff;

  /// No description provided for @actionSteeringHeatOn.
  ///
  /// In es, this message translates to:
  /// **'Calef. volante ON'**
  String get actionSteeringHeatOn;

  /// No description provided for @actionSteeringHeatOff.
  ///
  /// In es, this message translates to:
  /// **'Calef. volante OFF'**
  String get actionSteeringHeatOff;

  /// No description provided for @actionSunshadeOpen.
  ///
  /// In es, this message translates to:
  /// **'Persiana abrir'**
  String get actionSunshadeOpen;

  /// No description provided for @actionSunshadeClose.
  ///
  /// In es, this message translates to:
  /// **'Persiana cerrar'**
  String get actionSunshadeClose;

  /// No description provided for @actionWindowsOpen.
  ///
  /// In es, this message translates to:
  /// **'Ventanillas abrir'**
  String get actionWindowsOpen;

  /// No description provided for @actionWindowsClose.
  ///
  /// In es, this message translates to:
  /// **'Ventanillas cerrar'**
  String get actionWindowsClose;

  /// No description provided for @actionPreheatOn.
  ///
  /// In es, this message translates to:
  /// **'Precalentar ON'**
  String get actionPreheatOn;

  /// No description provided for @actionPreheatOff.
  ///
  /// In es, this message translates to:
  /// **'Precalentar OFF'**
  String get actionPreheatOff;

  /// No description provided for @speedLimitValue.
  ///
  /// In es, this message translates to:
  /// **'Limite: {speed} km/h'**
  String speedLimitValue(int speed);

  /// No description provided for @readingChargeLimit.
  ///
  /// In es, this message translates to:
  /// **'Leyendo limite de carga actual...'**
  String get readingChargeLimit;

  /// No description provided for @chargeLimitValue.
  ///
  /// In es, this message translates to:
  /// **'Limite de carga: {percent}%'**
  String chargeLimitValue(int percent);

  /// No description provided for @editFullScheduleButton.
  ///
  /// In es, this message translates to:
  /// **'Editar horario completo de carga'**
  String get editFullScheduleButton;

  /// No description provided for @seatDriverHeat.
  ///
  /// In es, this message translates to:
  /// **'Conductor - Calor'**
  String get seatDriverHeat;

  /// No description provided for @seatPassengerHeat.
  ///
  /// In es, this message translates to:
  /// **'Copiloto - Calor'**
  String get seatPassengerHeat;

  /// No description provided for @seatDriverVent.
  ///
  /// In es, this message translates to:
  /// **'Conductor - Ventilacion'**
  String get seatDriverVent;

  /// No description provided for @seatPassengerVent.
  ///
  /// In es, this message translates to:
  /// **'Copiloto - Ventilacion'**
  String get seatPassengerVent;

  /// No description provided for @aboutScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get aboutScreenTitle;

  /// No description provided for @appTagline.
  ///
  /// In es, this message translates to:
  /// **'App no oficial para Leapmotor'**
  String get appTagline;

  /// No description provided for @authorLabel.
  ///
  /// In es, this message translates to:
  /// **'Autor'**
  String get authorLabel;

  /// No description provided for @licenseLabel.
  ///
  /// In es, this message translates to:
  /// **'Licencia'**
  String get licenseLabel;

  /// No description provided for @licenseValue.
  ///
  /// In es, this message translates to:
  /// **'GNU General Public License v3.0 (GPLv3)'**
  String get licenseValue;

  /// No description provided for @repoLabel.
  ///
  /// In es, this message translates to:
  /// **'Repositorio y versiones'**
  String get repoLabel;

  /// No description provided for @disclaimerText.
  ///
  /// In es, this message translates to:
  /// **'Proyecto no oficial e independiente. No esta afiliado a, respaldado por, ni asociado con Leapmotor.'**
  String get disclaimerText;

  /// No description provided for @messagesScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Mensajes'**
  String get messagesScreenTitle;

  /// No description provided for @noMessages.
  ///
  /// In es, this message translates to:
  /// **'Sin mensajes.'**
  String get noMessages;

  /// No description provided for @noTitlePlaceholder.
  ///
  /// In es, this message translates to:
  /// **'(sin titulo)'**
  String get noTitlePlaceholder;

  /// No description provided for @debugScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Debug: estado completo'**
  String get debugScreenTitle;

  /// No description provided for @saveSnapshotButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar snapshot'**
  String get saveSnapshotButton;

  /// No description provided for @compareSnapshotButton.
  ///
  /// In es, this message translates to:
  /// **'Comparar con snapshot'**
  String get compareSnapshotButton;

  /// No description provided for @guardModeScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Modo Vigilancia (experimental)'**
  String get guardModeScreenTitle;

  /// No description provided for @guardModeWarning.
  ///
  /// In es, this message translates to:
  /// **'Solo para uso puntual y consciente, no para dejar el coche asi a diario: la ventanilla queda entreabierta durante parte del proceso, lo que reduce la seguridad fisica del vehiculo mientras dura la secuencia.'**
  String get guardModeWarning;

  /// No description provided for @videoCmdStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Experimental: comando de grabadora (cmd 290)'**
  String get videoCmdStepTitle;

  /// No description provided for @videoCmdDescription.
  ///
  /// In es, this message translates to:
  /// **'No sabemos que valor de \"operation\" espera el servidor. Prueba uno, luego usa el snapshot/diff en Debug, o entra al menu nativo del coche (Ajustes de la camara) para ver si el interruptor cambio de estado.'**
  String get videoCmdDescription;

  /// No description provided for @pendriveStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Pendrive con grabacion activada'**
  String get pendriveStepTitle;

  /// No description provided for @pendriveHint.
  ///
  /// In es, this message translates to:
  /// **'Verifica manualmente que el pendrive esta insertado y grabando.'**
  String get pendriveHint;

  /// No description provided for @ambientLightsStep.
  ///
  /// In es, this message translates to:
  /// **'Desactivar luces ambientales (menu del coche)'**
  String get ambientLightsStep;

  /// No description provided for @foldMirrorsStep.
  ///
  /// In es, this message translates to:
  /// **'Replegar espejos (acceso rapido o menu)'**
  String get foldMirrorsStep;

  /// No description provided for @headlightsOffStep.
  ///
  /// In es, this message translates to:
  /// **'Desactivar faros'**
  String get headlightsOffStep;

  /// No description provided for @screensOffStep.
  ///
  /// In es, this message translates to:
  /// **'Apagar pantallas'**
  String get screensOffStep;

  /// No description provided for @campingModeStep.
  ///
  /// In es, this message translates to:
  /// **'Modo acampada (experimental, no confirmado)'**
  String get campingModeStep;

  /// No description provided for @activateOn3.
  ///
  /// In es, this message translates to:
  /// **'Activar (ON3)'**
  String get activateOn3;

  /// No description provided for @deactivateOn3.
  ///
  /// In es, this message translates to:
  /// **'Desactivar (ON3)'**
  String get deactivateOn3;

  /// No description provided for @openWindowStep.
  ///
  /// In es, this message translates to:
  /// **'Abrir ventanilla del conductor'**
  String get openWindowStep;

  /// No description provided for @openWindowButton.
  ///
  /// In es, this message translates to:
  /// **'Abrir ventanilla'**
  String get openWindowButton;

  /// No description provided for @exitCarHint.
  ///
  /// In es, this message translates to:
  /// **'Sal del coche ahora con la ventanilla abierta antes de continuar.'**
  String get exitCarHint;

  /// No description provided for @lockCarStep.
  ///
  /// In es, this message translates to:
  /// **'Bloquear el coche'**
  String get lockCarStep;

  /// No description provided for @lockButton.
  ///
  /// In es, this message translates to:
  /// **'Bloquear'**
  String get lockButton;

  /// No description provided for @closeWindowStep.
  ///
  /// In es, this message translates to:
  /// **'Cerrar ventanilla (experimental tras bloqueo)'**
  String get closeWindowStep;

  /// No description provided for @closeWindowRemoteButton.
  ///
  /// In es, this message translates to:
  /// **'Intentar cerrar remotamente'**
  String get closeWindowRemoteButton;

  /// No description provided for @closeWindowFallbackHint.
  ///
  /// In es, this message translates to:
  /// **'Si este boton da error o la ventanilla no se mueve estando el coche bloqueado, sera necesario subirla a mano desde fuera como en el metodo original.'**
  String get closeWindowFallbackHint;

  /// No description provided for @preconditioningScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Precondicionado'**
  String get preconditioningScreenTitle;

  /// No description provided for @experimentalScheduleWarning.
  ///
  /// In es, this message translates to:
  /// **'Experimental: el formato exacto del horario se infiere por simetria con el codigo fuente de referencia, no esta 100% confirmado. Verificalo sintiendo si el coche realmente climatiza a la hora programada.'**
  String get experimentalScheduleWarning;

  /// No description provided for @modeLabel.
  ///
  /// In es, this message translates to:
  /// **'Modo'**
  String get modeLabel;

  /// No description provided for @heatChip.
  ///
  /// In es, this message translates to:
  /// **'Calor'**
  String get heatChip;

  /// No description provided for @coldChip.
  ///
  /// In es, this message translates to:
  /// **'Frio'**
  String get coldChip;

  /// No description provided for @temperatureLabel.
  ///
  /// In es, this message translates to:
  /// **'Temperatura: {temp}°C'**
  String temperatureLabel(int temp);

  /// No description provided for @steeringWheelHeatToggle.
  ///
  /// In es, this message translates to:
  /// **'Calefaccion de volante'**
  String get steeringWheelHeatToggle;

  /// No description provided for @prepareNowButton.
  ///
  /// In es, this message translates to:
  /// **'Precondicionar ahora (prueba inmediata)'**
  String get prepareNowButton;

  /// No description provided for @scheduleSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Programar'**
  String get scheduleSectionTitle;

  /// No description provided for @hourLabel.
  ///
  /// In es, this message translates to:
  /// **'Hora: {time}'**
  String hourLabel(String time);

  /// No description provided for @daysNoneSelectedHint.
  ///
  /// In es, this message translates to:
  /// **'Dias (ninguno seleccionado = una sola vez)'**
  String get daysNoneSelectedHint;

  /// No description provided for @addToScheduleButton.
  ///
  /// In es, this message translates to:
  /// **'Anadir a horario'**
  String get addToScheduleButton;

  /// No description provided for @scheduledEntriesTitle.
  ///
  /// In es, this message translates to:
  /// **'Entradas programadas'**
  String get scheduledEntriesTitle;

  /// No description provided for @noScheduledEntries.
  ///
  /// In es, this message translates to:
  /// **'Sin entradas programadas.'**
  String get noScheduledEntries;

  /// No description provided for @onceLabel.
  ///
  /// In es, this message translates to:
  /// **'Una vez'**
  String get onceLabel;

  /// No description provided for @dayShortSun.
  ///
  /// In es, this message translates to:
  /// **'Dom'**
  String get dayShortSun;

  /// No description provided for @dayShortMon.
  ///
  /// In es, this message translates to:
  /// **'Lun'**
  String get dayShortMon;

  /// No description provided for @dayShortTue.
  ///
  /// In es, this message translates to:
  /// **'Mar'**
  String get dayShortTue;

  /// No description provided for @dayShortWed.
  ///
  /// In es, this message translates to:
  /// **'Mie'**
  String get dayShortWed;

  /// No description provided for @dayShortThu.
  ///
  /// In es, this message translates to:
  /// **'Jue'**
  String get dayShortThu;

  /// No description provided for @dayShortFri.
  ///
  /// In es, this message translates to:
  /// **'Vie'**
  String get dayShortFri;

  /// No description provided for @dayShortSat.
  ///
  /// In es, this message translates to:
  /// **'Sab'**
  String get dayShortSat;

  /// No description provided for @chargeScheduleScreenTitle.
  ///
  /// In es, this message translates to:
  /// **'Horario de carga'**
  String get chargeScheduleScreenTitle;

  /// No description provided for @chargeScheduleExperimentalWarning.
  ///
  /// In es, this message translates to:
  /// **'Experimental: el formato de los dias de la semana (cycles) se infiere del valor por defecto ya usado en el limite de carga simple. Verifica con la pantalla de debug (snapshot/diff) tras guardar.'**
  String get chargeScheduleExperimentalWarning;

  /// No description provided for @scheduleActiveToggle.
  ///
  /// In es, this message translates to:
  /// **'Horario de carga activo'**
  String get scheduleActiveToggle;

  /// No description provided for @startTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Inicio: {time}'**
  String startTimeLabel(String time);

  /// No description provided for @endTimeLabel.
  ///
  /// In es, this message translates to:
  /// **'Fin: {time}'**
  String endTimeLabel(String time);

  /// No description provided for @weekdaysTitle.
  ///
  /// In es, this message translates to:
  /// **'Dias de la semana'**
  String get weekdaysTitle;

  /// No description provided for @saveScheduleButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar horario'**
  String get saveScheduleButton;

  /// No description provided for @lastUpdatedSeconds.
  ///
  /// In es, this message translates to:
  /// **'Actualizado hace {sec}s'**
  String lastUpdatedSeconds(int sec);

  /// No description provided for @lastUpdatedMinutes.
  ///
  /// In es, this message translates to:
  /// **'Actualizado hace {min} min'**
  String lastUpdatedMinutes(int min);

  /// No description provided for @lastUpdatedSecondsShort.
  ///
  /// In es, this message translates to:
  /// **'hace {sec}s'**
  String lastUpdatedSecondsShort(int sec);

  /// No description provided for @lastUpdatedMinutesShort.
  ///
  /// In es, this message translates to:
  /// **'hace {min} min'**
  String lastUpdatedMinutesShort(int min);

  /// No description provided for @rangeKmAutonomy.
  ///
  /// In es, this message translates to:
  /// **'{km} km autonomia'**
  String rangeKmAutonomy(String km);

  /// No description provided for @chargeHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de cargas'**
  String get chargeHistoryTitle;

  /// No description provided for @chargeHistorySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Detectado por la app desde su instalacion (no viene de Leapmotor).'**
  String get chargeHistorySubtitle;

  /// No description provided for @noChargeDetected.
  ///
  /// In es, this message translates to:
  /// **'Aun no se ha detectado ninguna carga.'**
  String get noChargeDetected;

  /// No description provided for @ongoingLabel.
  ///
  /// In es, this message translates to:
  /// **'en curso'**
  String get ongoingLabel;

  /// No description provided for @consumptionCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Consumo y autonomia real'**
  String get consumptionCardTitle;

  /// No description provided for @collectingDataMsg.
  ///
  /// In es, this message translates to:
  /// **'Recopilando datos de conduccion ({count} puntos). Necesita varios trayectos con la app abierta.'**
  String collectingDataMsg(int count);

  /// No description provided for @notEnoughDataMsg.
  ///
  /// In es, this message translates to:
  /// **'Sin datos suficientes de conduccion detectados aun (solo cargas/parado).'**
  String get notEnoughDataMsg;

  /// No description provided for @avgConsumptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Consumo medio: {percent}% cada 100 km'**
  String avgConsumptionLabel(String percent);

  /// No description provided for @estimatedRangeLabel.
  ///
  /// In es, this message translates to:
  /// **'Autonomia estimada (segun tu consumo real): {km} km'**
  String estimatedRangeLabel(int km);

  /// No description provided for @reportedRangeLabel.
  ///
  /// In es, this message translates to:
  /// **'Autonomia que reporta el coche: {km} km'**
  String reportedRangeLabel(int km);

  /// No description provided for @worseEfficiencyMsg.
  ///
  /// In es, this message translates to:
  /// **'Tu conduccion gasta mas que la estimacion del fabricante.'**
  String get worseEfficiencyMsg;

  /// No description provided for @betterEfficiencyMsg.
  ///
  /// In es, this message translates to:
  /// **'Tu conduccion es mas eficiente que la estimacion del fabricante.'**
  String get betterEfficiencyMsg;

  /// No description provided for @weeklyEfficiencyTitle.
  ///
  /// In es, this message translates to:
  /// **'Eficiencia: esta semana vs anterior'**
  String get weeklyEfficiencyTitle;

  /// No description provided for @thisWeekLabel.
  ///
  /// In es, this message translates to:
  /// **'Esta semana'**
  String get thisWeekLabel;

  /// No description provided for @lastWeekLabel.
  ///
  /// In es, this message translates to:
  /// **'Semana anterior'**
  String get lastWeekLabel;

  /// No description provided for @betterThisWeekMsg.
  ///
  /// In es, this message translates to:
  /// **'Esta semana consumes menos que la anterior (mejor eficiencia).'**
  String get betterThisWeekMsg;

  /// No description provided for @worseThisWeekMsg.
  ///
  /// In es, this message translates to:
  /// **'Esta semana consumes mas que la anterior.'**
  String get worseThisWeekMsg;

  /// No description provided for @needBothWeeksMsg.
  ///
  /// In es, this message translates to:
  /// **'Necesita datos de conduccion de ambas semanas para comparar.'**
  String get needBothWeeksMsg;

  /// No description provided for @percentPer100kmFmt.
  ///
  /// In es, this message translates to:
  /// **'{value}%/100km'**
  String percentPer100kmFmt(String value);

  /// No description provided for @tirePressureTitle.
  ///
  /// In es, this message translates to:
  /// **'Presion de neumaticos'**
  String get tirePressureTitle;

  /// No description provided for @tireFrontLeft.
  ///
  /// In es, this message translates to:
  /// **'Del. izq.'**
  String get tireFrontLeft;

  /// No description provided for @tireFrontRight.
  ///
  /// In es, this message translates to:
  /// **'Del. der.'**
  String get tireFrontRight;

  /// No description provided for @tireRearLeft.
  ///
  /// In es, this message translates to:
  /// **'Tras. izq.'**
  String get tireRearLeft;

  /// No description provided for @tireRearRight.
  ///
  /// In es, this message translates to:
  /// **'Tras. der.'**
  String get tireRearRight;

  /// No description provided for @barUnit.
  ///
  /// In es, this message translates to:
  /// **'{value} bar'**
  String barUnit(String value);

  /// No description provided for @resolvingAddress.
  ///
  /// In es, this message translates to:
  /// **'Buscando direccion...'**
  String get resolvingAddress;

  /// No description provided for @parkedNear.
  ///
  /// In es, this message translates to:
  /// **'Aparcado cerca de {address}'**
  String parkedNear(String address);

  /// No description provided for @enableLocationPermission.
  ///
  /// In es, this message translates to:
  /// **'Activa el permiso de ubicacion para ver la distancia'**
  String get enableLocationPermission;

  /// No description provided for @enableGps.
  ///
  /// In es, this message translates to:
  /// **'Activa el GPS para ver la distancia'**
  String get enableGps;

  /// No description provided for @distanceFromCurrentPosition.
  ///
  /// In es, this message translates to:
  /// **'A {distance} de tu posicion actual'**
  String distanceFromCurrentPosition(String distance);

  /// No description provided for @couldNotResolveAddress.
  ///
  /// In es, this message translates to:
  /// **'No se pudo resolver la direccion'**
  String get couldNotResolveAddress;

  /// No description provided for @hotspotStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Experimental: WiFi/hotspot (cmd 140)'**
  String get hotspotStepTitle;

  /// No description provided for @hotspotDescription.
  ///
  /// In es, this message translates to:
  /// **'No confirmado que hace este comando: podria ser el hotspot WiFi de pasajeros, o algo relacionado con mantener el coche conectado a tu red domestica (o ninguna de las dos). Prueba una variante y verifica con snapshot/diff, o comprobando si tu router ve al coche conectado despues de bloquearlo.'**
  String get hotspotDescription;

  /// No description provided for @tileBatteryTemp.
  ///
  /// In es, this message translates to:
  /// **'Temp. bateria'**
  String get tileBatteryTemp;

  /// No description provided for @tileInteriorTemp.
  ///
  /// In es, this message translates to:
  /// **'Temp. interior'**
  String get tileInteriorTemp;

  /// No description provided for @tileOutdoorTemp.
  ///
  /// In es, this message translates to:
  /// **'Temp. exterior (estimada)'**
  String get tileOutdoorTemp;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
