// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'LMB10';

  @override
  String get loginScreenTitle => 'Iniciar sesion';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Contrasena';

  @override
  String get pinLabel => 'PIN del vehiculo';

  @override
  String get pinHelper =>
      'Necesario para bloquear/desbloquear, clima, asientos, etc.';

  @override
  String get rememberPinTitle => 'Recordar PIN en este dispositivo';

  @override
  String get rememberPinSubtitle =>
      'Se guarda cifrado localmente (flutter_secure_storage).';

  @override
  String get loginButton => 'Login';

  @override
  String get dashboardDefaultTitle => 'Leapmotor';

  @override
  String get refreshTooltip => 'Actualizar';

  @override
  String get settingsTooltip => 'Ajustes, logs y backups';

  @override
  String get aboutTooltip => 'Acerca de';

  @override
  String get logoutTooltip => 'Cerrar sesion';

  @override
  String get tileBattery => 'Bateria';

  @override
  String get tileAutonomy => 'Autonomia';

  @override
  String get tileLock => 'Cerradura';

  @override
  String get lockedLabel => 'Cerrado';

  @override
  String get unlockedLabel => 'Abierto';

  @override
  String get tileChargeState => 'Estado carga';

  @override
  String get chargingLabel => 'Cargando';

  @override
  String get notChargingLabel => 'Sin carga';

  @override
  String get disconnectedLabel => 'Desconectado';

  @override
  String get tileChargeCable => 'Cable carga';

  @override
  String get connectedLabel => 'Conectado';

  @override
  String get disconnectedShortLabel => 'Desconect.';

  @override
  String get tileThermalMgmt => 'Gestion termica';

  @override
  String get activeLabel => 'Activa';

  @override
  String get normalLabel => 'Normal';

  @override
  String get tileClimate => 'Clima';

  @override
  String get onLabel => 'Encendido';

  @override
  String get offLabel => 'Apagada';

  @override
  String get tileTrunk => 'Maletero';

  @override
  String get openLabel => 'Abierto';

  @override
  String get closedLabel => 'Cerrado';

  @override
  String get tileSentry => 'Centinela';

  @override
  String get activeShortLabel => 'Activo';

  @override
  String get inactiveLabel => 'Inactivo';

  @override
  String get controlsButton => 'Controles del vehiculo';

  @override
  String get guardModeButton => 'Modo Vigilancia (experimental)';

  @override
  String get preconditioningButton => 'Precondicionado';

  @override
  String get messagesButton => 'Mensajes';

  @override
  String get exportButton => 'Exportar datos (JSON anonimizado)';

  @override
  String get debugButton => 'Ver estado completo (debug)';

  @override
  String get pinDialogTitle => 'PIN del vehiculo';

  @override
  String get pinDialogCancel => 'Cancelar';

  @override
  String get pinDialogAccept => 'Aceptar';

  @override
  String get noLocationData => 'Sin datos de ubicacion';

  @override
  String get controlsScreenTitle => 'Controles del vehiculo';

  @override
  String get sectionSentry => 'Centinela';

  @override
  String get sectionActions => 'Acciones';

  @override
  String get sectionClimate => 'Climatizacion';

  @override
  String get sectionComfort => 'Confort';

  @override
  String get sectionSunshadeWindows => 'Persiana y ventanas';

  @override
  String get sectionSpeedLimit => 'Limite de velocidad';

  @override
  String get sectionBattery => 'Bateria';

  @override
  String get sectionSeats => 'Asientos';

  @override
  String get actionSentryOn => 'Centinela ON';

  @override
  String get actionSentryOff => 'Centinela OFF';

  @override
  String get actionLock => 'Bloquear';

  @override
  String get actionUnlock => 'Desbloquear';

  @override
  String get actionTrunkOpen => 'Maletero abrir';

  @override
  String get actionTrunkClose => 'Maletero cerrar';

  @override
  String get actionFindCar => 'Localizar';

  @override
  String get actionUnlockCharger => 'Desbloq. cargador';

  @override
  String get actionQuickHeat => 'Calentar rapido';

  @override
  String get actionQuickCool => 'Enfriar rapido';

  @override
  String get actionDefrost => 'Desempanar parabrisas';

  @override
  String get actionAcOff => 'Apagar clima';

  @override
  String get actionSteeringHeatOn => 'Calef. volante ON';

  @override
  String get actionSteeringHeatOff => 'Calef. volante OFF';

  @override
  String get actionSunshadeOpen => 'Persiana abrir';

  @override
  String get actionSunshadeClose => 'Persiana cerrar';

  @override
  String get actionWindowsOpen => 'Ventanillas abrir';

  @override
  String get actionWindowsClose => 'Ventanillas cerrar';

  @override
  String get actionPreheatOn => 'Precalentar ON';

  @override
  String get actionPreheatOff => 'Precalentar OFF';

  @override
  String speedLimitValue(int speed) {
    return 'Limite: $speed km/h';
  }

  @override
  String get readingChargeLimit => 'Leyendo limite de carga actual...';

  @override
  String chargeLimitValue(int percent) {
    return 'Limite de carga: $percent%';
  }

  @override
  String get editFullScheduleButton => 'Editar horario completo de carga';

  @override
  String get seatDriverHeat => 'Conductor - Calor';

  @override
  String get seatPassengerHeat => 'Copiloto - Calor';

  @override
  String get seatDriverVent => 'Conductor - Ventilacion';

  @override
  String get seatPassengerVent => 'Copiloto - Ventilacion';

  @override
  String get aboutScreenTitle => 'Acerca de';

  @override
  String get appTagline => 'App no oficial para Leapmotor';

  @override
  String get authorLabel => 'Autor';

  @override
  String get licenseLabel => 'Licencia';

  @override
  String get licenseValue => 'GNU General Public License v3.0 (GPLv3)';

  @override
  String get repoLabel => 'Repositorio y versiones';

  @override
  String get disclaimerText =>
      'Proyecto no oficial e independiente. No esta afiliado a, respaldado por, ni asociado con Leapmotor.';

  @override
  String get messagesScreenTitle => 'Mensajes';

  @override
  String get noMessages => 'Sin mensajes.';

  @override
  String get noTitlePlaceholder => '(sin titulo)';

  @override
  String get debugScreenTitle => 'Debug: estado completo';

  @override
  String get saveSnapshotButton => 'Guardar snapshot';

  @override
  String get compareSnapshotButton => 'Comparar con snapshot';

  @override
  String get guardModeScreenTitle => 'Modo Vigilancia (experimental)';

  @override
  String get guardModeWarning =>
      'Solo para uso puntual y consciente, no para dejar el coche asi a diario: la ventanilla queda entreabierta durante parte del proceso, lo que reduce la seguridad fisica del vehiculo mientras dura la secuencia.';

  @override
  String get videoCmdStepTitle =>
      'Experimental: comando de grabadora (cmd 290)';

  @override
  String get videoCmdDescription =>
      'No sabemos que valor de \"operation\" espera el servidor. Prueba uno, luego usa el snapshot/diff en Debug, o entra al menu nativo del coche (Ajustes de la camara) para ver si el interruptor cambio de estado.';

  @override
  String get pendriveStepTitle => 'Pendrive con grabacion activada';

  @override
  String get pendriveHint =>
      'Verifica manualmente que el pendrive esta insertado y grabando.';

  @override
  String get ambientLightsStep =>
      'Desactivar luces ambientales (menu del coche)';

  @override
  String get foldMirrorsStep => 'Replegar espejos (acceso rapido o menu)';

  @override
  String get headlightsOffStep => 'Desactivar faros';

  @override
  String get screensOffStep => 'Apagar pantallas';

  @override
  String get campingModeStep => 'Modo acampada (experimental, no confirmado)';

  @override
  String get activateOn3 => 'Activar (ON3)';

  @override
  String get deactivateOn3 => 'Desactivar (ON3)';

  @override
  String get openWindowStep => 'Abrir ventanilla del conductor';

  @override
  String get openWindowButton => 'Abrir ventanilla';

  @override
  String get exitCarHint =>
      'Sal del coche ahora con la ventanilla abierta antes de continuar.';

  @override
  String get lockCarStep => 'Bloquear el coche';

  @override
  String get lockButton => 'Bloquear';

  @override
  String get closeWindowStep => 'Cerrar ventanilla (experimental tras bloqueo)';

  @override
  String get closeWindowRemoteButton => 'Intentar cerrar remotamente';

  @override
  String get closeWindowFallbackHint =>
      'Si este boton da error o la ventanilla no se mueve estando el coche bloqueado, sera necesario subirla a mano desde fuera como en el metodo original.';

  @override
  String get preconditioningScreenTitle => 'Precondicionado';

  @override
  String get experimentalScheduleWarning =>
      'Experimental: el formato exacto del horario se infiere por simetria con el codigo fuente de referencia, no esta 100% confirmado. Verificalo sintiendo si el coche realmente climatiza a la hora programada.';

  @override
  String get modeLabel => 'Modo';

  @override
  String get heatChip => 'Calor';

  @override
  String get coldChip => 'Frio';

  @override
  String temperatureLabel(int temp) {
    return 'Temperatura: $temp°C';
  }

  @override
  String get steeringWheelHeatToggle => 'Calefaccion de volante';

  @override
  String get prepareNowButton => 'Precondicionar ahora (prueba inmediata)';

  @override
  String get scheduleSectionTitle => 'Programar';

  @override
  String hourLabel(String time) {
    return 'Hora: $time';
  }

  @override
  String get daysNoneSelectedHint =>
      'Dias (ninguno seleccionado = una sola vez)';

  @override
  String get addToScheduleButton => 'Anadir a horario';

  @override
  String get scheduledEntriesTitle => 'Entradas programadas';

  @override
  String get noScheduledEntries => 'Sin entradas programadas.';

  @override
  String get onceLabel => 'Una vez';

  @override
  String get dayShortSun => 'Dom';

  @override
  String get dayShortMon => 'Lun';

  @override
  String get dayShortTue => 'Mar';

  @override
  String get dayShortWed => 'Mie';

  @override
  String get dayShortThu => 'Jue';

  @override
  String get dayShortFri => 'Vie';

  @override
  String get dayShortSat => 'Sab';

  @override
  String get chargeScheduleScreenTitle => 'Horario de carga';

  @override
  String get chargeScheduleExperimentalWarning =>
      'Experimental: el formato de los dias de la semana (cycles) se infiere del valor por defecto ya usado en el limite de carga simple. Verifica con la pantalla de debug (snapshot/diff) tras guardar.';

  @override
  String get scheduleActiveToggle => 'Horario de carga activo';

  @override
  String startTimeLabel(String time) {
    return 'Inicio: $time';
  }

  @override
  String endTimeLabel(String time) {
    return 'Fin: $time';
  }

  @override
  String get weekdaysTitle => 'Dias de la semana';

  @override
  String get saveScheduleButton => 'Guardar horario';

  @override
  String lastUpdatedSeconds(int sec) {
    return 'Actualizado hace ${sec}s';
  }

  @override
  String lastUpdatedMinutes(int min) {
    return 'Actualizado hace $min min';
  }

  @override
  String lastUpdatedSecondsShort(int sec) {
    return 'hace ${sec}s';
  }

  @override
  String lastUpdatedMinutesShort(int min) {
    return 'hace $min min';
  }

  @override
  String rangeKmAutonomy(String km) {
    return '$km km autonomia';
  }

  @override
  String get chargeHistoryTitle => 'Historial de cargas';

  @override
  String get chargeHistorySubtitle =>
      'Detectado por la app desde su instalacion (no viene de Leapmotor).';

  @override
  String get noChargeDetected => 'Aun no se ha detectado ninguna carga.';

  @override
  String get ongoingLabel => 'en curso';

  @override
  String get consumptionCardTitle => 'Consumo y autonomia real';

  @override
  String collectingDataMsg(int count) {
    return 'Recopilando datos de conduccion ($count puntos). Necesita varios trayectos con la app abierta.';
  }

  @override
  String get notEnoughDataMsg =>
      'Sin datos suficientes de conduccion detectados aun (solo cargas/parado).';

  @override
  String avgConsumptionLabel(String percent) {
    return 'Consumo medio: $percent% cada 100 km';
  }

  @override
  String estimatedRangeLabel(int km) {
    return 'Autonomia estimada (segun tu consumo real): $km km';
  }

  @override
  String reportedRangeLabel(int km) {
    return 'Autonomia que reporta el coche: $km km';
  }

  @override
  String get worseEfficiencyMsg =>
      'Tu conduccion gasta mas que la estimacion del fabricante.';

  @override
  String get betterEfficiencyMsg =>
      'Tu conduccion es mas eficiente que la estimacion del fabricante.';

  @override
  String get weeklyEfficiencyTitle => 'Eficiencia: esta semana vs anterior';

  @override
  String get thisWeekLabel => 'Esta semana';

  @override
  String get lastWeekLabel => 'Semana anterior';

  @override
  String get betterThisWeekMsg =>
      'Esta semana consumes menos que la anterior (mejor eficiencia).';

  @override
  String get worseThisWeekMsg => 'Esta semana consumes mas que la anterior.';

  @override
  String get needBothWeeksMsg =>
      'Necesita datos de conduccion de ambas semanas para comparar.';

  @override
  String percentPer100kmFmt(String value) {
    return '$value%/100km';
  }

  @override
  String get tirePressureTitle => 'Presion de neumaticos';

  @override
  String get tireFrontLeft => 'Del. izq.';

  @override
  String get tireFrontRight => 'Del. der.';

  @override
  String get tireRearLeft => 'Tras. izq.';

  @override
  String get tireRearRight => 'Tras. der.';

  @override
  String barUnit(String value) {
    return '$value bar';
  }

  @override
  String get resolvingAddress => 'Buscando direccion...';

  @override
  String parkedNear(String address) {
    return 'Aparcado cerca de $address';
  }

  @override
  String get enableLocationPermission =>
      'Activa el permiso de ubicacion para ver la distancia';

  @override
  String get enableGps => 'Activa el GPS para ver la distancia';

  @override
  String distanceFromCurrentPosition(String distance) {
    return 'A $distance de tu posicion actual';
  }

  @override
  String get couldNotResolveAddress => 'No se pudo resolver la direccion';

  @override
  String get hotspotStepTitle => 'Experimental: WiFi/hotspot (cmd 140)';

  @override
  String get hotspotDescription =>
      'No confirmado que hace este comando: podria ser el hotspot WiFi de pasajeros, o algo relacionado con mantener el coche conectado a tu red domestica (o ninguna de las dos). Prueba una variante y verifica con snapshot/diff, o comprobando si tu router ve al coche conectado despues de bloquearlo.';

  @override
  String get tileBatteryTemp => 'Temp. bateria';

  @override
  String get tileInteriorTemp => 'Temp. interior';

  @override
  String get tileOutdoorTemp => 'Temp. exterior (estimada)';
}
